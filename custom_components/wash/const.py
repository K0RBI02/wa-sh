"""Konstanten der wa:sh-Integration."""

from __future__ import annotations

from datetime import timedelta
from typing import Final

DOMAIN: Final = "wash"

CONF_WEBHOOK_ID: Final = "webhook_id"
CONF_CLOUDHOOK_URL: Final = "cloudhook_url"

MACHINES: Final = ("wash", "dry")
MACHINE_NAMES: Final = {"wash": "Waschmaschine", "dry": "Trockner"}

STATE_IDLE: Final = "idle"
STATE_RUNNING: Final = "running"
STATE_FINISHED: Final = "finished"
STATES: Final = [STATE_IDLE, STATE_RUNNING, STATE_FINISHED]

# Ereignisse auf dem HA-Bus – für Automationen.
EVENT_STARTED: Final = "wash_started"
EVENT_FINISHED: Final = "wash_finished"
EVENT_COLLECTED: Final = "wash_collected"

# Kopplung
PAIR_CODE_TTL: Final = timedelta(minutes=10)
PAIR_CODE_ALPHABET: Final = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # ohne 0/O, 1/I
PAIR_MAX_FAILS: Final = 10  # pro IP und 10 Minuten

PROGRESS_INTERVAL: Final = timedelta(seconds=30)
STORAGE_VERSION: Final = 1
