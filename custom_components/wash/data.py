"""Zustand von Waschmaschine und Trockner – empfängt den Webhook der App."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from http import HTTPStatus
import logging
from typing import Any

from aiohttp import web

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import (
    async_track_point_in_utc_time,
    async_track_time_interval,
)
from homeassistant.helpers.storage import Store
from homeassistant.util import dt as dt_util

from .const import (
    DOMAIN,
    EVENT_COLLECTED,
    EVENT_FINISHED,
    EVENT_STARTED,
    MACHINE_NAMES,
    MACHINES,
    PROGRESS_INTERVAL,
    STATE_FINISHED,
    STATE_IDLE,
    STATE_RUNNING,
    STATES,
    STORAGE_VERSION,
)

_LOGGER = logging.getLogger(__name__)


@dataclass
class MachineState:
    """Was die App zuletzt gemeldet hat."""

    state: str = STATE_IDLE
    program: str | None = None
    start: datetime | None = None
    end: datetime | None = None

    def effective(self, now: datetime) -> str:
        """„running“ wird von selbst zu „finished“, sobald die Zeit um ist –
        auch wenn das Handy gerade nichts meldet."""
        if self.state == STATE_RUNNING and self.end is not None and now >= self.end:
            return STATE_FINISHED
        return self.state

    def progress(self, now: datetime) -> int:
        if self.start is None or self.end is None:
            return 0
        if self.effective(now) == STATE_FINISHED:
            return 100
        if self.state != STATE_RUNNING:
            return 0
        total = (self.end - self.start).total_seconds()
        if total <= 0:
            return 100
        done = (now - self.start).total_seconds()
        return max(0, min(100, round(done / total * 100)))

    def remaining_minutes(self, now: datetime) -> int | None:
        if self.effective(now) != STATE_RUNNING or self.end is None:
            return None
        return max(0, int((self.end - now).total_seconds() + 59) // 60)

    def as_dict(self) -> dict[str, Any]:
        return {
            "state": self.state,
            "program": self.program,
            "start": self.start.isoformat() if self.start else None,
            "end": self.end.isoformat() if self.end else None,
        }

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> MachineState:
        state = raw.get("state")
        return cls(
            state=state if state in STATES else STATE_IDLE,
            program=raw.get("program"),
            start=_parse(raw.get("start")),
            end=_parse(raw.get("end")),
        )


def _parse(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    parsed = dt_util.parse_datetime(value)
    if parsed is None:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt_util.UTC)
    return dt_util.as_utc(parsed)


class WashData:
    """Laufzeitdaten eines Eintrags."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self.machines: dict[str, MachineState] = {m: MachineState() for m in MACHINES}
        self.signal = f"{DOMAIN}_{entry.entry_id}_update"
        self._store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, f"{DOMAIN}.{entry.entry_id}")
        self._timers: dict[str, CALLBACK_TYPE] = {}
        self._tick: CALLBACK_TYPE | None = None
        self.last_seen: datetime | None = None

    # ── Laden / Speichern ─────────────────────────────────────────

    async def async_load(self) -> None:
        raw = await self._store.async_load() or {}
        for m in MACHINES:
            if isinstance(raw.get(m), dict):
                self.machines[m] = MachineState.from_dict(raw[m])
        self.last_seen = _parse(raw.get("last_seen"))
        for m in MACHINES:
            self._schedule(m)
        self._tick = async_track_time_interval(self.hass, self._on_tick, PROGRESS_INTERVAL)

    @callback
    def _save(self) -> None:
        self._store.async_delay_save(self._snapshot, 1)

    @callback
    def _snapshot(self) -> dict[str, Any]:
        data: dict[str, Any] = {m: s.as_dict() for m, s in self.machines.items()}
        data["last_seen"] = self.last_seen.isoformat() if self.last_seen else None
        return data

    @callback
    def async_shutdown(self) -> None:
        for cancel in self._timers.values():
            cancel()
        self._timers.clear()
        if self._tick:
            self._tick()
            self._tick = None

    async def async_remove(self) -> None:
        await self._store.async_remove()

    # ── Webhook ──────────────────────────────────────────────────

    async def handle_webhook(
        self, hass: HomeAssistant, webhook_id: str, request: web.Request
    ) -> web.Response:
        try:
            body = await request.json()
        except ValueError:
            return web.json_response({"ok": False, "error": "kein JSON"}, status=HTTPStatus.BAD_REQUEST)
        if not isinstance(body, dict):
            return web.json_response({"ok": False, "error": "kein Objekt"}, status=HTTPStatus.BAD_REQUEST)

        self.last_seen = dt_util.utcnow()
        kind = body.get("type", "update")

        if kind == "ping":
            self._save()
            return web.json_response({"ok": True, "name": self.entry.title})

        if kind != "update":
            return web.json_response({"ok": False, "error": "unbekannter Typ"}, status=HTTPStatus.BAD_REQUEST)

        machine = body.get("machine")
        state = body.get("state")
        if machine not in MACHINES or state not in STATES:
            return web.json_response(
                {"ok": False, "error": "machine/state ungültig"}, status=HTTPStatus.BAD_REQUEST
            )

        self.async_apply(machine, MachineState.from_dict(body))
        return web.json_response({"ok": True})

    @callback
    def async_apply(self, machine: str, new: MachineState) -> None:
        """Neuen Stand übernehmen, Ereignisse feuern, Ablauf planen."""
        now = dt_util.utcnow()
        old = self.machines[machine]
        before = old.effective(now)
        self.machines[machine] = new
        after = new.effective(now)

        if after == STATE_RUNNING and (before != STATE_RUNNING or new.start != old.start):
            self._fire(EVENT_STARTED, machine)
        elif after == STATE_FINISHED and before != STATE_FINISHED:
            self._fire(EVENT_FINISHED, machine)
        elif after == STATE_IDLE and before == STATE_FINISHED:
            self._fire(EVENT_COLLECTED, machine)

        self._schedule(machine)
        self._save()
        async_dispatcher_send(self.hass, self.signal)

    # ── Zeitsteuerung ─────────────────────────────────────────────

    @callback
    def _schedule(self, machine: str) -> None:
        if cancel := self._timers.pop(machine, None):
            cancel()
        s = self.machines[machine]
        if s.state == STATE_RUNNING and s.end is not None and s.end > dt_util.utcnow():

            @callback
            def _done(_now: datetime) -> None:
                self._timers.pop(machine, None)
                # Fest auf „fertig“ setzen – nicht auf die Uhrzeit verlassen,
                # der Timer kann ein paar Millisekunden zu früh feuern.
                self.machines[machine].state = STATE_FINISHED
                self._save()
                self._fire(EVENT_FINISHED, machine)
                async_dispatcher_send(self.hass, self.signal)

            self._timers[machine] = async_track_point_in_utc_time(self.hass, _done, s.end)

    @callback
    def _on_tick(self, _now: datetime) -> None:
        if any(s.state == STATE_RUNNING for s in self.machines.values()):
            async_dispatcher_send(self.hass, self.signal)

    @callback
    def _fire(self, event: str, machine: str) -> None:
        s = self.machines[machine]
        self.hass.bus.async_fire(
            event,
            {
                "entry_id": self.entry.entry_id,
                "machine": machine,
                "name": MACHINE_NAMES[machine],
                "program": s.program,
                "end": s.end.isoformat() if s.end else None,
            },
        )
        _LOGGER.debug("%s: %s", event, machine)
