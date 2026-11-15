"""Binärsensor „läuft“ – praktisch für Automationen."""

from __future__ import annotations

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
)
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.util import dt as dt_util

from . import WashConfigEntry
from .const import MACHINES, STATE_RUNNING
from .entity import WashEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: WashConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities(WashRunning(entry.runtime_data, m) for m in MACHINES)


class WashRunning(WashEntity, BinarySensorEntity):
    _attr_device_class = BinarySensorDeviceClass.RUNNING

    def __init__(self, data, machine: str) -> None:
        super().__init__(data, machine, "running")

    @property
    def is_on(self) -> bool:
        return self.state_data.effective(dt_util.utcnow()) == STATE_RUNNING
