"""Kopplung App ↔ Home Assistant über einen kurzlebigen Code.

Ablauf: Beim Hinzufügen der Integration (oder später über „Konfigurieren“)
zeigt HA einen Code wie ``K7Q-2M9``. Die App schickt ihn zusammen mit der
HA-Adresse an ``/api/wash/pair`` und bekommt die Webhook-Daten zurück.
Codes gelten 10 Minuten, nur einmal, und Fehlversuche sind begrenzt.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from http import HTTPStatus
import secrets

from aiohttp import web

from homeassistant.components.http import KEY_HASS, HomeAssistantView
from homeassistant.core import HomeAssistant, callback
from homeassistant.util import dt as dt_util

from .const import (
    CONF_CLOUDHOOK_URL,
    CONF_WEBHOOK_ID,
    DOMAIN,
    PAIR_CODE_ALPHABET,
    PAIR_CODE_TTL,
    PAIR_MAX_FAILS,
)

_DATA_KEY = f"{DOMAIN}_pairing"


@dataclass
class _Pairing:
    codes: dict[str, tuple[str, datetime]] = field(default_factory=dict)
    fails: dict[str, list[datetime]] = field(default_factory=dict)


def _state(hass: HomeAssistant) -> _Pairing:
    return hass.data.setdefault(_DATA_KEY, _Pairing())


def normalize(code: str) -> str:
    """„k7q 2m9“ → „K7Q2M9“."""
    return "".join(ch for ch in code.upper() if ch.isalnum())


def pretty(code: str) -> str:
    return f"{code[:3]}-{code[3:]}"


@callback
def async_new_code(hass: HomeAssistant, webhook_id: str) -> str:
    """Neuen Code für einen Eintrag erzeugen; ältere Codes desselben Eintrags verfallen."""
    state = _state(hass)
    state.codes = {c: v for c, v in state.codes.items() if v[0] != webhook_id}
    code = "".join(secrets.choice(PAIR_CODE_ALPHABET) for _ in range(6))
    state.codes[code] = (webhook_id, dt_util.utcnow() + PAIR_CODE_TTL)
    return pretty(code)


@callback
def async_redeem(hass: HomeAssistant, code: str) -> str | None:
    """Code einlösen → webhook_id, oder None wenn ungültig/abgelaufen."""
    state = _state(hass)
    now = dt_util.utcnow()
    state.codes = {c: v for c, v in state.codes.items() if v[1] > now}
    hit = state.codes.pop(normalize(code), None)
    return hit[0] if hit else None


@callback
def _too_many_fails(hass: HomeAssistant, remote: str) -> bool:
    state = _state(hass)
    cutoff = dt_util.utcnow() - PAIR_CODE_TTL
    recent = [t for t in state.fails.get(remote, []) if t > cutoff]
    state.fails[remote] = recent
    return len(recent) >= PAIR_MAX_FAILS


@callback
def _note_fail(hass: HomeAssistant, remote: str) -> None:
    _state(hass).fails.setdefault(remote, []).append(dt_util.utcnow())


class WashPairView(HomeAssistantView):
    """``POST /api/wash/pair`` – ohne Anmeldung, geschützt durch den Code."""

    url = "/api/wash/pair"
    name = "api:wash:pair"
    requires_auth = False

    async def post(self, request: web.Request) -> web.Response:
        hass = request.app[KEY_HASS]
        remote = request.remote or "?"

        if _too_many_fails(hass, remote):
            return self.json_message("Zu viele Versuche – bitte später erneut.", HTTPStatus.TOO_MANY_REQUESTS)

        try:
            body = await request.json()
            code = str(body["code"])
        except (ValueError, KeyError, TypeError):
            return self.json_message("Ungültige Anfrage.", HTTPStatus.BAD_REQUEST)

        webhook_id = async_redeem(hass, code)
        entry = None
        if webhook_id is not None:
            entry = next(
                (
                    e
                    for e in hass.config_entries.async_entries(DOMAIN)
                    if e.data.get(CONF_WEBHOOK_ID) == webhook_id
                ),
                None,
            )
        if entry is None:
            _note_fail(hass, remote)
            return self.json_message("Code ungültig oder abgelaufen.", HTTPStatus.NOT_FOUND)

        return self.json(
            {
                "name": entry.title,
                "webhook_id": webhook_id,
                "cloudhook_url": entry.data.get(CONF_CLOUDHOOK_URL),
            }
        )
