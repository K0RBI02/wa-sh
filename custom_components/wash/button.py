"""Knöpfe je Maschine: Starten (mit dem gewählten Programm) und Abgeholt."""

from __future__ import annotations

from homeassistant.components.button import ButtonEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.util import dt as dt_util

from . import WashConfigEntry
from .const import MACHINES, STATE_IDLE, STATE_RUNNING
from .entity import WashEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: WashConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    data = entry.runtime_data
    async_add_entities(
        [WashStartButton(data, m) for m in MACHINES] + [WashCollectButton(data, m) for m in MACHINES]
    )


class WashStartButton(WashEntity, ButtonEntity):
    """Startet den Timer mit dem Programm aus der Auswahl."""

    def __init__(self, data, machine: str) -> None:
        super().__init__(data, machine, "start")

    @property
    def available(self) -> bool:
        running = self.state_data.effective(dt_util.utcnow()) == STATE_RUNNING
        return not running and bool(self.data.program_names(self.machine))

    async def async_press(self) -> None:
        program = self.data.resolve_program(self.machine, None)
        if program is not None:
            self.data.async_start(self.machine, name=program["name"], minutes=program["minutes"])


class WashCollectButton(WashEntity, ButtonEntity):
    """Wäsche abgeholt (bzw. Timer abbrechen) – Maschine wieder frei."""

    def __init__(self, data, machine: str) -> None:
        super().__init__(data, machine, "collect")

    @property
    def available(self) -> bool:
        return self.state_data.effective(dt_util.utcnow()) != STATE_IDLE

    async def async_press(self) -> None:
        self.data.async_collect(self.machine)
