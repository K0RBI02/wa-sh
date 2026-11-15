"""Gemeinsame Basis: ein Gerät pro Maschine."""

from __future__ import annotations

from homeassistant.core import callback
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity import Entity

from .const import DOMAIN, MACHINE_NAMES
from .data import MachineState, WashData


class WashEntity(Entity):
    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, data: WashData, machine: str, key: str) -> None:
        self.data = data
        self.machine = machine
        entry = data.entry
        self._attr_unique_id = f"{entry.entry_id}_{machine}_{key}"
        self._attr_translation_key = key
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, f"{entry.entry_id}_{machine}")},
            name=MACHINE_NAMES[machine],
            manufacturer="wa:sh",
            model="Wäsche-Timer",
            suggested_area=entry.title,
        )

    @property
    def state_data(self) -> MachineState:
        return self.data.machines[self.machine]

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(
            async_dispatcher_connect(self.hass, self.data.signal, self._refresh)
        )

    @callback
    def _refresh(self) -> None:
        self.async_write_ha_state()
