"""Einrichtung in drei Schritten: Name → Code (wartet aufs Handy) → fertig."""

from __future__ import annotations

import asyncio
from typing import Any

import voluptuous as vol

from homeassistant.components import webhook
from homeassistant.config_entries import (
    ConfigEntry,
    ConfigFlow,
    ConfigFlowResult,
    OptionsFlow,
)
from homeassistant.const import CONF_NAME
from homeassistant.core import HomeAssistant, callback

from .const import CONF_CLOUDHOOK_URL, CONF_WEBHOOK_ID, DOMAIN, PAIR_CODE_TTL
from .pairing import PendingPair, async_discard, async_new_code

_MINUTES = str(int(PAIR_CODE_TTL.total_seconds() // 60))


class _PairingMixin:
    """Gemeinsamer Ablauf für Einrichten und „neues Handy koppeln“."""

    hass: HomeAssistant
    _pending: PendingPair | None = None
    _code: str = ""
    _task: asyncio.Task[bool] | None = None

    def _pair_ids(self) -> tuple[str, str, str | None]:
        raise NotImplementedError

    async def _wait(self, pending: PendingPair) -> bool:
        try:
            async with asyncio.timeout(PAIR_CODE_TTL.total_seconds()):
                await pending.paired.wait()
        except TimeoutError:
            async_discard(self.hass, pending)
            return False
        return True

    async def async_step_pair(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Schritt 2: Code groß anzeigen und warten, bis die App ihn einlöst."""
        if self._task is None:
            webhook_id, title, cloudhook = self._pair_ids()
            self._code, self._pending = async_new_code(self.hass, webhook_id, title, cloudhook)
            self._task = self.hass.async_create_task(self._wait(self._pending), eager_start=False)

        if not self._task.done():
            return self.async_show_progress(  # type: ignore[attr-defined]
                step_id="pair",
                progress_action="pair",
                description_placeholders={"code": self._code, "minutes": _MINUTES},
                progress_task=self._task,
            )

        ok = self._task.result()
        self._task = None
        return self.async_show_progress_done(next_step_id="paired" if ok else "expired")  # type: ignore[attr-defined]

    async def async_step_expired(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Code abgelaufen → auf Wunsch neuen erzeugen."""
        if user_input is not None:
            return await self.async_step_pair()
        return self.async_show_form(step_id="expired", data_schema=vol.Schema({}))  # type: ignore[attr-defined]

    def async_remove(self) -> None:
        """Dialog geschlossen: Code ungültig machen."""
        if self._task and not self._task.done():
            self._task.cancel()
        if self._pending:
            async_discard(self.hass, self._pending)


class WashConfigFlow(_PairingMixin, ConfigFlow, domain=DOMAIN):
    """Ein Eintrag = ein Waschraum (Waschmaschine + Trockner)."""

    VERSION = 1

    def __init__(self) -> None:
        self._title = ""
        self._webhook_id = ""
        self._cloudhook: str | None = None

    def _pair_ids(self) -> tuple[str, str, str | None]:
        return self._webhook_id, self._title, self._cloudhook

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Schritt 1: Name."""
        if user_input is None:
            return self.async_show_form(
                step_id="user",
                data_schema=vol.Schema({vol.Required(CONF_NAME, default="Waschküche"): str}),
            )

        self._title = user_input[CONF_NAME].strip() or "Waschküche"
        self._webhook_id = webhook.async_generate_id()
        # Mit Nabu Casa: zusätzlich eine Cloud-Adresse, damit die App auch von
        # unterwegs (z. B. aus dem Keller ohne WLAN) melden kann.
        if "cloud" in self.hass.config.components:
            from homeassistant.components import cloud  # noqa: PLC0415 – nur wenn Cloud aktiv

            try:
                if cloud.async_active_subscription(self.hass):
                    self._cloudhook = await cloud.async_create_cloudhook(self.hass, self._webhook_id)
            except Exception:  # noqa: BLE001 – Cloud ist optional
                self._cloudhook = None
        return await self.async_step_pair()

    async def async_step_paired(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Schritt 3: gekoppelt – Eintrag anlegen."""
        return self.async_create_entry(
            title=self._title,
            data={CONF_WEBHOOK_ID: self._webhook_id, CONF_CLOUDHOOK_URL: self._cloudhook},
            description_placeholders={"name": self._title},
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        return WashOptionsFlow()


class WashOptionsFlow(_PairingMixin, OptionsFlow):
    """„Konfigurieren“ → weiteres Handy koppeln."""

    def _pair_ids(self) -> tuple[str, str, str | None]:
        e = self.config_entry
        return e.data[CONF_WEBHOOK_ID], e.title, e.data.get(CONF_CLOUDHOOK_URL)

    async def async_step_init(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        return await self.async_step_pair()

    async def async_step_paired(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        return self.async_abort(reason="paired", description_placeholders={"name": self.config_entry.title})
