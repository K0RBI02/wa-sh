"""Ende-zu-Ende: Einrichtung, Kopplung, Webhook, Ablauf, Neustart."""

from __future__ import annotations

from datetime import timedelta

import pytest

from homeassistant import config_entries
from homeassistant.core import HomeAssistant
from homeassistant.data_entry_flow import FlowResultType
from homeassistant.helpers import entity_registry as er
from homeassistant.setup import async_setup_component
from homeassistant.util import dt as dt_util

from pytest_homeassistant_custom_component.common import (
    async_capture_events,
    async_fire_time_changed,
)

from custom_components.wash.const import DOMAIN


async def _setup(hass: HomeAssistant):
    assert await async_setup_component(hass, "http", {})
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": config_entries.SOURCE_USER})
    assert result["type"] is FlowResultType.FORM
    result = await hass.config_entries.flow.async_configure(result["flow_id"], {"name": "Waschküche"})
    assert result["type"] is FlowResultType.CREATE_ENTRY
    await hass.async_block_till_done()
    entry = result["result"]
    return entry, result["description_placeholders"]["code"]


def _entity(hass: HomeAssistant, entry, machine: str, key: str, domain: str = "sensor") -> str:
    reg = er.async_get(hass)
    eid = reg.async_get_entity_id(domain, DOMAIN, f"{entry.entry_id}_{machine}_{key}")
    assert eid, f"{domain} {machine}_{key} fehlt"
    return eid


async def test_einrichtung_zeigt_code_und_legt_entitaeten_an(hass: HomeAssistant) -> None:
    entry, code = await _setup(hass)
    assert entry.title == "Waschküche"
    assert len(code) == 7 and code[3] == "-"
    for m in ("wash", "dry"):
        assert hass.states.get(_entity(hass, entry, m, "status")).state == "idle"
        assert hass.states.get(_entity(hass, entry, m, "running", "binary_sensor")).state == "off"


async def test_kopplung(hass: HomeAssistant, hass_client_no_auth) -> None:
    entry, code = await _setup(hass)
    client = await hass_client_no_auth()

    resp = await client.post("/api/wash/pair", json={"code": code.lower().replace("-", " ")})
    assert resp.status == 200
    body = await resp.json()
    assert body["webhook_id"] == entry.data["webhook_id"]
    assert body["name"] == "Waschküche"

    # Nur einmal gültig
    resp = await client.post("/api/wash/pair", json={"code": code})
    assert resp.status == 404


async def test_kopplung_falscher_code_und_sperre(hass: HomeAssistant, hass_client_no_auth) -> None:
    await _setup(hass)
    client = await hass_client_no_auth()
    for _ in range(10):
        assert (await client.post("/api/wash/pair", json={"code": "ZZZ-ZZZ"})).status == 404
    assert (await client.post("/api/wash/pair", json={"code": "ZZZ-ZZZ"})).status == 429
    assert (await client.post("/api/wash/pair", data="kaputt")).status in (400, 429)


async def test_neuer_code_ueber_konfigurieren(hass: HomeAssistant, hass_client_no_auth) -> None:
    entry, old = await _setup(hass)
    result = await hass.config_entries.options.async_init(entry.entry_id)
    assert result["type"] is FlowResultType.FORM
    new = result["description_placeholders"]["code"]
    assert new != old
    client = await hass_client_no_auth()
    assert (await client.post("/api/wash/pair", json={"code": old})).status == 404
    assert (await client.post("/api/wash/pair", json={"code": new})).status == 200


async def test_ablauf_start_fertig_abgeholt(hass: HomeAssistant, hass_client_no_auth) -> None:
    entry, _ = await _setup(hass)
    client = await hass_client_no_auth()
    url = f"/api/webhook/{entry.data['webhook_id']}"
    started = async_capture_events(hass, "wash_started")
    finished = async_capture_events(hass, "wash_finished")
    collected = async_capture_events(hass, "wash_collected")

    resp = await client.post(url, json={"type": "ping"})
    assert (await resp.json())["ok"] is True

    now = dt_util.utcnow()
    end = now + timedelta(minutes=47)
    resp = await client.post(
        url,
        json={
            "type": "update",
            "machine": "wash",
            "state": "running",
            "program": "Bunt 40°",
            "start": (now - timedelta(minutes=58)).isoformat(),
            "end": end.isoformat(),
        },
    )
    assert resp.status == 200
    await hass.async_block_till_done()

    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "running"
    assert hass.states.get(_entity(hass, entry, "wash", "running", "binary_sensor")).state == "on"
    assert hass.states.get(_entity(hass, entry, "wash", "program")).state == "Bunt 40°"
    assert int(hass.states.get(_entity(hass, entry, "wash", "remaining")).state) == 47
    assert 50 <= int(hass.states.get(_entity(hass, entry, "wash", "progress")).state) <= 60
    assert dt_util.parse_datetime(hass.states.get(_entity(hass, entry, "wash", "finish")).state) is not None
    assert hass.states.get(_entity(hass, entry, "dry", "status")).state == "idle", "Trockner unabhängig"
    assert len(started) == 1

    # Zeit vergeht – HA merkt „fertig“ selbst, ohne Meldung der App.
    async_fire_time_changed(hass, end + timedelta(seconds=1))
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "finished"
    assert hass.states.get(_entity(hass, entry, "wash", "running", "binary_sensor")).state == "off"
    assert len(finished) == 1
    assert finished[0].data["machine"] == "wash"

    # Abgeholt
    await client.post(url, json={"type": "update", "machine": "wash", "state": "idle"})
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "idle"
    assert len(collected) == 1


async def test_ungueltige_meldungen(hass: HomeAssistant, hass_client_no_auth) -> None:
    entry, _ = await _setup(hass)
    client = await hass_client_no_auth()
    url = f"/api/webhook/{entry.data['webhook_id']}"
    assert (await client.post(url, data="kein json")).status == 400
    assert (await client.post(url, json={"type": "update", "machine": "spuele", "state": "running"})).status == 400
    assert (await client.post(url, json={"type": "update", "machine": "wash", "state": "kaputt"})).status == 400
    assert (await client.post(url, json={"type": "foo"})).status == 400


async def test_zustand_uebersteht_neustart(hass: HomeAssistant, hass_client_no_auth) -> None:
    entry, _ = await _setup(hass)
    client = await hass_client_no_auth()
    now = dt_util.utcnow()
    await client.post(
        f"/api/webhook/{entry.data['webhook_id']}",
        json={
            "type": "update",
            "machine": "dry",
            "state": "running",
            "program": "Baumwolle",
            "start": now.isoformat(),
            "end": (now + timedelta(minutes=100)).isoformat(),
        },
    )
    await hass.async_block_till_done()
    async_fire_time_changed(hass, now + timedelta(seconds=5))  # gespeichert wird verzögert
    await hass.async_block_till_done()

    assert await hass.config_entries.async_reload(entry.entry_id)
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "dry", "status")).state == "running"
    assert hass.states.get(_entity(hass, entry, "dry", "program")).state == "Baumwolle"


@pytest.mark.parametrize("machine", ["wash", "dry"])
async def test_entfernen_raeumt_auf(hass: HomeAssistant, machine: str) -> None:
    entry, _ = await _setup(hass)
    assert await hass.config_entries.async_remove(entry.entry_id)
    await hass.async_block_till_done()
    assert hass.states.get(f"sensor.{machine}_status") is None
