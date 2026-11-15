"""Einrichtung über „Integration hinzufügen“ – zeigt den Kopplungscode für die App."""

from __future__ import annotations

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
from homeassistant.core import callback

from .const import CONF_CLOUDHOOK_URL, CONF_WEBHOOK_ID, DOMAIN, PAIR_CODE_TTL
from .pairing import async_new_code

_MINUTES = str(int(PAIR_CODE_TTL.total_seconds() // 60))


class WashConfigFlow(ConfigFlow, domain=DOMAIN):
    """Ein Eintrag = ein Waschraum (Waschmaschine + Trockner)."""

    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is None:
            return self.async_show_form(
                step_id="user",
                data_schema=vol.Schema({vol.Required(CONF_NAME, default="Waschküche"): str}),
            )

        webhook_id = webhook.async_generate_id()
        cloudhook_url: str | None = None
        # Mit Nabu Casa: zusätzlich eine Cloud-Adresse, damit die App auch von
        # unterwegs (z. B. aus dem Keller ohne WLAN) melden kann.
        if "cloud" in self.hass.config.components:
            from homeassistant.components import cloud  # noqa: PLC0415 – nur wenn Cloud aktiv

            try:
                if cloud.async_active_subscription(self.hass):
                    cloudhook_url = await cloud.async_create_cloudhook(self.hass, webhook_id)
            except Exception:  # noqa: BLE001 – Cloud ist optional
                cloudhook_url = None

        code = async_new_code(self.hass, webhook_id)
        return self.async_create_entry(
            title=user_input[CONF_NAME],
            data={CONF_WEBHOOK_ID: webhook_id, CONF_CLOUDHOOK_URL: cloudhook_url},
            description_placeholders={"code": code, "minutes": _MINUTES},
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        return WashOptionsFlow()


class WashOptionsFlow(OptionsFlow):
    """„Konfigurieren“ → neuen Kopplungscode anzeigen (z. B. für ein neues Handy)."""

    async def async_step_init(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data=dict(self.config_entry.options))
        code = async_new_code(self.hass, self.config_entry.data[CONF_WEBHOOK_ID])
        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema({}),
            description_placeholders={"code": code, "minutes": _MINUTES},
        )
