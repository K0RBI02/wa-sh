"""Diagnosedaten (Eintrag → ⋮ → Diagnose herunterladen) – ohne Geheimnisse."""

from __future__ import annotations

from typing import Any

from homeassistant.components.diagnostics import async_redact_data
from homeassistant.core import HomeAssistant
from homeassistant.util import dt as dt_util

from . import WashConfigEntry
from .const import CONF_CLOUDHOOK_URL, CONF_WEBHOOK_ID

TO_REDACT = {CONF_WEBHOOK_ID, CONF_CLOUDHOOK_URL}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: WashConfigEntry
) -> dict[str, Any]:
    data = entry.runtime_data
    now = dt_util.utcnow()
    return {
        "entry": async_redact_data(entry.as_dict(), TO_REDACT),
        "last_seen": data.last_seen.isoformat() if data.last_seen else None,
        "machines": {
            m: {**s.as_dict(), "effective": s.effective(now), "progress": s.progress(now)}
            for m, s in data.machines.items()
        },
    }
