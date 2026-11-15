"""wa:sh – Waschmaschine und Trockner aus der wa:sh-App in Home Assistant.

Die App meldet Start, Programm und Endzeit per Webhook direkt an diese
Integration – ohne Zwischenserver. Die Integration kennt damit selbst den
Zeitpunkt „fertig“ und meldet ihn auch, wenn das Handy gerade aus ist.
"""

from __future__ import annotations

from homeassistant.components import webhook
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType

from .const import CONF_CLOUDHOOK_URL, CONF_WEBHOOK_ID, DOMAIN
from .data import WashData
from .pairing import WashPairView

PLATFORMS: list[Platform] = [Platform.BINARY_SENSOR, Platform.SENSOR]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

type WashConfigEntry = ConfigEntry[WashData]


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Kopplungs-Endpunkt einmalig bereitstellen."""
    hass.http.register_view(WashPairView())
    return True


async def async_setup_entry(hass: HomeAssistant, entry: WashConfigEntry) -> bool:
    data = WashData(hass, entry)
    await data.async_load()
    entry.runtime_data = data

    webhook_id = entry.data[CONF_WEBHOOK_ID]
    webhook.async_register(
        hass,
        DOMAIN,
        entry.title,
        webhook_id,
        data.handle_webhook,
        local_only=False,
        allowed_methods=["POST"],
    )
    entry.async_on_unload(lambda: webhook.async_unregister(hass, webhook_id))
    entry.async_on_unload(data.async_shutdown)

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: WashConfigEntry) -> bool:
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)


async def async_remove_entry(hass: HomeAssistant, entry: WashConfigEntry) -> None:
    """Beim Löschen: Cloud-Adresse und gespeicherten Zustand mit aufräumen."""
    if entry.data.get(CONF_CLOUDHOOK_URL) and "cloud" in hass.config.components:
        try:
            from homeassistant.components import cloud  # noqa: PLC0415 – nur wenn Cloud aktiv

            await cloud.async_delete_cloudhook(hass, entry.data[CONF_WEBHOOK_ID])
        except Exception:  # noqa: BLE001 – Aufräumen darf das Löschen nicht blockieren
            pass
    await WashData(hass, entry).async_remove()
