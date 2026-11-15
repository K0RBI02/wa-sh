"""Aktionen wash.start und wash.collect – z. B. für Automationen oder Sprachbefehle."""

from __future__ import annotations

import voluptuous as vol

from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import HomeAssistant, ServiceCall, callback
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import config_validation as cv

from .const import DOMAIN, MACHINES

ATTR_ENTRY = "config_entry_id"
ATTR_MACHINE = "machine"
ATTR_PROGRAM = "program"
ATTR_MINUTES = "minutes"

_BASE = {
    vol.Optional(ATTR_ENTRY): cv.string,
    vol.Required(ATTR_MACHINE): vol.In(MACHINES),
}
START_SCHEMA = vol.Schema(
    {
        **_BASE,
        vol.Optional(ATTR_PROGRAM): cv.string,
        vol.Optional(ATTR_MINUTES): vol.All(vol.Coerce(int), vol.Range(min=1, max=600)),
    }
)
COLLECT_SCHEMA = vol.Schema(_BASE)


def _data(hass: HomeAssistant, call: ServiceCall):
    entries = [
        e
        for e in hass.config_entries.async_entries(DOMAIN)
        if e.state is ConfigEntryState.LOADED
        and (ATTR_ENTRY not in call.data or e.entry_id == call.data[ATTR_ENTRY])
    ]
    if not entries:
        raise ServiceValidationError(translation_domain=DOMAIN, translation_key="no_entry")
    return entries[0].runtime_data


@callback
def async_setup_services(hass: HomeAssistant) -> None:
    async def start(call: ServiceCall) -> None:
        data = _data(hass, call)
        machine = call.data[ATTR_MACHINE]
        if ATTR_MINUTES in call.data:
            data.async_start(machine, name=call.data.get(ATTR_PROGRAM) or "Home Assistant", minutes=call.data[ATTR_MINUTES])
            return
        program = data.resolve_program(machine, call.data.get(ATTR_PROGRAM))
        if program is None:
            raise ServiceValidationError(translation_domain=DOMAIN, translation_key="unknown_program")
        data.async_start(machine, name=program["name"], minutes=program["minutes"])

    async def collect(call: ServiceCall) -> None:
        _data(hass, call).async_collect(call.data[ATTR_MACHINE])

    hass.services.async_register(DOMAIN, "start", start, schema=START_SCHEMA)
    hass.services.async_register(DOMAIN, "collect", collect, schema=COLLECT_SCHEMA)
