"""Kopplung App ↔ Home Assistant über einen kurzlebigen Code.

Ablauf: Beim Einrichten (oder später über „Konfigurieren“) zeigt HA einen
Code wie ``K7Q-2M9`` und wartet. Die App schickt ihn zusammen mit der
HA-Adresse an ``/api/wash/pair``; HA meldet dem wartenden Dialog „gekoppelt“
und gibt der App die Webhook-Daten zurück.
Codes gelten 10 Minuten, nur einmal, und Fehlversuche sind begrenzt.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime
from http import HTTPStatus
import secrets

from aiohttp import web

from homeassistant.components.http import KEY_HASS, HomeAssistantView
from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import HomeAssistant, callback
from homeassistant.util import dt as dt_util

from .const import (
    CONF_WEBHOOK_ID,
    DOMAIN,
    PAIR_CODE_ALPHABET,
    PAIR_CODE_TTL,
    PAIR_MAX_FAILS,
)

_DATA_KEY = f"{DOMAIN}_pairing"
# So lange wartet die App-Anfrage, bis der Eintrag in HA bereit ist.
_READY_TIMEOUT = 10


@dataclass
class PendingPair:
    """Ein angezeigter Code, auf den ein Dialog wartet."""

    webhook_id: str
    title: str
    cloudhook_url: str | None
    expires: datetime
    paired: asyncio.Event = field(default_factory=asyncio.Event)


@dataclass
class _Pairing:
    codes: dict[str, PendingPair] = field(default_factory=dict)
    fails: dict[str, list[datetime]] = field(default_factory=dict)
    view: bool = False


def _state(hass: HomeAssistant) -> _Pairing:
    return hass.data.setdefault(_DATA_KEY, _Pairing())


def normalize(code: str) -> str:
    """„k7q 2m9“ → „K7Q2M9“."""
    return "".join(ch for ch in code.upper() if ch.isalnum())


def pretty(code: str) -> str:
    return f"{code[:3]}-{code[3:]}"


@callback
def async_register_view(hass: HomeAssistant) -> None:
    """Endpunkt einmalig anmelden – auch schon während der ersten Einrichtung,
    wenn die Integration selbst noch nicht geladen ist."""
    state = _state(hass)
    if not state.view:
        hass.http.register_view(WashPairView())
        state.view = True


@callback
def async_new_code(
    hass: HomeAssistant, webhook_id: str, title: str, cloudhook_url: str | None
) -> tuple[str, PendingPair]:
    """Neuen Code erzeugen; ältere Codes derselben Kopplung verfallen."""
    async_register_view(hass)
    state = _state(hass)
    state.codes = {c: p for c, p in state.codes.items() if p.webhook_id != webhook_id}
    code = "".join(secrets.choice(PAIR_CODE_ALPHABET) for _ in range(6))
    pending = PendingPair(webhook_id, title, cloudhook_url, dt_util.utcnow() + PAIR_CODE_TTL)
    state.codes[code] = pending
    return pretty(code), pending


@callback
def async_discard(hass: HomeAssistant, pending: PendingPair) -> None:
    """Code zurückziehen (Dialog abgebrochen oder abgelaufen)."""
    state = _state(hass)
    state.codes = {c: p for c, p in state.codes.items() if p is not pending}


@callback
def async_redeem(hass: HomeAssistant, code: str) -> PendingPair | None:
    """Code einlösen, oder None wenn ungültig/abgelaufen."""
    state = _state(hass)
    now = dt_util.utcnow()
    state.codes = {c: p for c, p in state.codes.items() if p.expires > now}
    return state.codes.pop(normalize(code), None)


@callback
def _too_many_fails(hass: HomeAssistant, remote: str) -> bool:
    state = _state(hass)
    cutoff = dt_util.utcnow() - PAIR_CODE_TTL
    recent = [t for t in state.fails.get(remote, []) if t > cutoff]
    state.fails[remote] = recent
    return len(recent) >= PAIR_MAX_FAILS


@callback
def _note_fail(hass: HomeAssistant, remote: str) -> None:
    _state(hass).fails.setdefault(remote, []).append(dt_util.utcnow())


def _entry_ready(hass: HomeAssistant, webhook_id: str) -> bool:
    return any(
        e.data.get(CONF_WEBHOOK_ID) == webhook_id and e.state is ConfigEntryState.LOADED
        for e in hass.config_entries.async_entries(DOMAIN)
    )


class WashPairView(HomeAssistantView):
    """``POST /api/wash/pair`` – ohne Anmeldung, geschützt durch den Code."""

    url = "/api/wash/pair"
    name = "api:wash:pair"
    requires_auth = False

    async def post(self, request: web.Request) -> web.Response:
        hass = request.app[KEY_HASS]
        remote = request.remote or "?"

        if _too_many_fails(hass, remote):
            return self.json_message("Zu viele Versuche – bitte später erneut.", HTTPStatus.TOO_MANY_REQUESTS)

        try:
            body = await request.json()
            code = str(body["code"])
        except (ValueError, KeyError, TypeError):
            return self.json_message("Ungültige Anfrage.", HTTPStatus.BAD_REQUEST)

        pending = async_redeem(hass, code)
        if pending is None:
            _note_fail(hass, remote)
            return self.json_message("Code ungültig oder abgelaufen.", HTTPStatus.NOT_FOUND)

        # Wartenden Dialog weiterschalten …
        pending.paired.set()
        # … und kurz warten, bis der Eintrag läuft – dann kommt die erste
        # Meldung der App gleich richtig an.
        for _ in range(_READY_TIMEOUT * 10):
            if _entry_ready(hass, pending.webhook_id):
                break
            await asyncio.sleep(0.1)

        return self.json(
            {
                "name": pending.title,
                "webhook_id": pending.webhook_id,
                "cloudhook_url": pending.cloudhook_url,
            }
        )
