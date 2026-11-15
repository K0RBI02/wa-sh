"""Sensoren je Maschine: Status, Fertig um, Restzeit, Fortschritt, Programm."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
)
from homeassistant.const import PERCENTAGE, UnitOfTime
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.util import dt as dt_util

from . import WashConfigEntry
from .const import MACHINES, STATE_FINISHED, STATE_RUNNING, STATES
from .data import MachineState
from .entity import WashEntity


@dataclass(frozen=True, kw_only=True)
class WashSensorDescription(SensorEntityDescription):
    value: Callable[[MachineState, datetime], object]


SENSORS: tuple[WashSensorDescription, ...] = (
    WashSensorDescription(
        key="status",
        device_class=SensorDeviceClass.ENUM,
        options=STATES,
        value=lambda s, now: s.effective(now),
    ),
    WashSensorDescription(
        key="finish",
        device_class=SensorDeviceClass.TIMESTAMP,
        value=lambda s, now: s.end if s.effective(now) == STATE_RUNNING else None,
    ),
    WashSensorDescription(
        key="remaining",
        device_class=SensorDeviceClass.DURATION,
        native_unit_of_measurement=UnitOfTime.MINUTES,
        value=lambda s, now: s.remaining_minutes(now),
    ),
    WashSensorDescription(
        key="progress",
        native_unit_of_measurement=PERCENTAGE,
        value=lambda s, now: s.progress(now),
    ),
    WashSensorDescription(
        key="program",
        value=lambda s, now: s.program if s.effective(now) in (STATE_RUNNING, STATE_FINISHED) else None,
    ),
)

_ICONS = {
    "wash": {"idle": "mdi:washing-machine-off", "running": "mdi:washing-machine", "finished": "mdi:washing-machine-alert"},
    "dry": {"idle": "mdi:tumble-dryer-off", "running": "mdi:tumble-dryer", "finished": "mdi:tumble-dryer-alert"},
}


async def async_setup_entry(
    hass: HomeAssistant,
    entry: WashConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities(
        WashSensor(entry.runtime_data, m, d) for m in MACHINES for d in SENSORS
    )


class WashSensor(WashEntity, SensorEntity):
    entity_description: WashSensorDescription

    def __init__(self, data, machine: str, description: WashSensorDescription) -> None:
        super().__init__(data, machine, description.key)
        self.entity_description = description

    @property
    def native_value(self):
        return self.entity_description.value(self.state_data, dt_util.utcnow())

    @property
    def icon(self) -> str | None:
        if self.entity_description.key != "status":
            return None
        return _ICONS[self.machine][self.state_data.effective(dt_util.utcnow())]
