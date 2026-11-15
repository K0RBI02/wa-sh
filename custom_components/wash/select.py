"""Programmauswahl je Maschine – die zwei Lieblingsprogramme aus der App."""

from __future__ import annotations

from homeassistant.components.select import SelectEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import WashConfigEntry
from .const import MACHINES
from .entity import WashEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: WashConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities(WashProgramSelect(entry.runtime_data, m) for m in MACHINES)


class WashProgramSelect(WashEntity, SelectEntity):
    """Welches Programm „Starten“ nimmt."""

    def __init__(self, data, machine: str) -> None:
        super().__init__(data, machine, "program_select")

    @property
    def available(self) -> bool:
        # Erst wenn die App ihre Programme gemeldet hat.
        return bool(self.data.program_names(self.machine))

    @property
    def options(self) -> list[str]:
        return self.data.program_names(self.machine)

    @property
    def current_option(self) -> str | None:
        names = self.data.program_names(self.machine)
        sel = self.data.selected[self.machine]
        if sel in names:
            return sel
        return names[0] if names else None

    async def async_select_option(self, option: str) -> None:
        self.data.async_select(self.machine, option)
