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
from custom_components.wash.pairing import async_register_view


async def _start(hass: HomeAssistant, name: str = "Waschküche"):
    """Schritte 1 und 2: Name eingeben → Code wird angezeigt, Dialog wartet."""
    assert await async_setup_component(hass, "http", {})
    result = await hass.config_entries.flow.async_init(DOMAIN, context={"source": config_entries.SOURCE_USER})
    assert result["type"] is FlowResultType.FORM
    result = await hass.config_entries.flow.async_configure(result["flow_id"], {"name": name})
    assert result["type"] is FlowResultType.SHOW_PROGRESS
    assert result["step_id"] == "pair"
    return result["flow_id"], result["description_placeholders"]["code"]


async def _setup(hass: HomeAssistant, client):
    """Kompletter Ablauf inkl. Kopplung durch die „App“."""
    flow_id, code = await _start(hass)
    resp = await client.post("/api/wash/pair", json={"code": code})
    assert resp.status == 200
    body = await resp.json()
    await hass.async_block_till_done()
    result = await hass.config_entries.flow.async_configure(flow_id)
    assert result["type"] is FlowResultType.CREATE_ENTRY
    await hass.async_block_till_done()
    return result["result"], body


@pytest.fixture
async def client(hass: HomeAssistant, hass_client_no_auth, monkeypatch):
    # Im echten Betrieb wartet die Antwort, bis der Dialog den Eintrag angelegt
    # hat (das macht dort das Frontend). Im Test gibt es kein Frontend.
    monkeypatch.setattr("custom_components.wash.pairing._READY_TIMEOUT", 0)
    # Im Test friert der Client die Routen ein – also vorher alles anmelden.
    assert await async_setup_component(hass, "http", {})
    assert await async_setup_component(hass, "webhook", {})
    async_register_view(hass)
    return await hass_client_no_auth()


def _entity(hass: HomeAssistant, entry, machine: str, key: str, domain: str = "sensor") -> str:
    reg = er.async_get(hass)
    eid = reg.async_get_entity_id(domain, DOMAIN, f"{entry.entry_id}_{machine}_{key}")
    assert eid, f"{domain} {machine}_{key} fehlt"
    return eid


async def test_drei_schritte_und_kopplung(hass: HomeAssistant, client) -> None:
    flow_id, code = await _start(hass)
    assert len(code) == 7 and code[3] == "-"
    assert not hass.config_entries.async_entries(DOMAIN), "erst nach Kopplung anlegen"

    # App koppelt (Kleinschreibung, Leerzeichen egal)
    resp = await client.post("/api/wash/pair", json={"code": code.lower().replace("-", " ")})
    assert resp.status == 200
    body = await resp.json()
    assert body["name"] == "Waschküche"
    await hass.async_block_till_done()

    # Dialog geht von selbst weiter → Schritt 3
    result = await hass.config_entries.flow.async_configure(flow_id)
    assert result["type"] is FlowResultType.CREATE_ENTRY
    entry = result["result"]
    assert body["webhook_id"] == entry.data["webhook_id"]
    await hass.async_block_till_done()
    for m in ("wash", "dry"):
        assert hass.states.get(_entity(hass, entry, m, "status")).state == "idle"
        assert hass.states.get(_entity(hass, entry, m, "running", "binary_sensor")).state == "off"
    assert hass.states.get(_entity(hass, entry, "wash", "running", "binary_sensor")).attributes["icon"] == "mdi:washing-machine-off"
    assert hass.states.get(_entity(hass, entry, "dry", "status")).attributes["icon"] == "mdi:tumble-dryer-off"

    # Code nur einmal gültig
    assert (await client.post("/api/wash/pair", json={"code": code})).status == 404


async def test_code_laeuft_ab(hass: HomeAssistant, client) -> None:
    flow_id, code = await _start(hass)
    hass.config_entries.flow.async_abort(flow_id)  # Dialog geschlossen
    await hass.async_block_till_done()
    assert (await client.post("/api/wash/pair", json={"code": code})).status == 404


async def test_falscher_code_und_sperre(hass: HomeAssistant, client) -> None:
    await _start(hass)
    for _ in range(10):
        assert (await client.post("/api/wash/pair", json={"code": "ZZZ-ZZZ"})).status == 404
    assert (await client.post("/api/wash/pair", json={"code": "ZZZ-ZZZ"})).status == 429


async def test_weiteres_handy_ueber_konfigurieren(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    result = await hass.config_entries.options.async_init(entry.entry_id)
    assert result["type"] is FlowResultType.SHOW_PROGRESS
    code = result["description_placeholders"]["code"]
    resp = await client.post("/api/wash/pair", json={"code": code})
    assert (await resp.json())["webhook_id"] == entry.data["webhook_id"]
    await hass.async_block_till_done()
    result = await hass.config_entries.options.async_configure(result["flow_id"])
    assert result["type"] is FlowResultType.ABORT
    assert result["reason"] == "paired"


async def test_ablauf_start_fertig_abgeholt(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
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

    await client.post(url, json={"type": "update", "machine": "wash", "state": "idle"})
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "idle"
    assert len(collected) == 1


async def test_ungueltige_meldungen(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    url = f"/api/webhook/{entry.data['webhook_id']}"
    assert (await client.post(url, data="kein json")).status == 400
    assert (await client.post(url, json={"type": "update", "machine": "spuele", "state": "running"})).status == 400
    assert (await client.post(url, json={"type": "update", "machine": "wash", "state": "kaputt"})).status == 400
    assert (await client.post(url, json={"type": "foo"})).status == 400


async def test_zustand_uebersteht_neustart(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
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


async def test_diagnose_ohne_geheimnisse(hass: HomeAssistant, client) -> None:
    from custom_components.wash.diagnostics import async_get_config_entry_diagnostics

    entry, _ = await _setup(hass, client)
    diag = await async_get_config_entry_diagnostics(hass, entry)
    text = str(diag)
    assert entry.data["webhook_id"] not in text
    assert diag["machines"]["wash"]["effective"] == "idle"


async def test_entfernen_raeumt_auf(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    assert await hass.config_entries.async_remove(entry.entry_id)
    await hass.async_block_till_done()
    assert hass.states.get("sensor.waschmaschine_status") is None


PROGRAMS = {
    "wash": [{"name": "Bunt 40°", "minutes": 105}, {"name": "Handtücher 60°", "minutes": 130}],
    "dry": [{"name": "Baumwolle", "minutes": 100}, {"name": "Pflegeleicht", "minutes": 60}],
}


async def test_starten_und_abholen_aus_ha(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    url = f"/api/webhook/{entry.data['webhook_id']}"
    reg = er.async_get(hass)
    select = reg.async_get_entity_id("select", DOMAIN, f"{entry.entry_id}_wash_program_select")
    start = reg.async_get_entity_id("button", DOMAIN, f"{entry.entry_id}_wash_start")
    collect = reg.async_get_entity_id("button", DOMAIN, f"{entry.entry_id}_wash_collect")

    # Ohne Programme der App: nicht verfügbar
    assert hass.states.get(start).state == "unavailable"

    resp = await client.post(url, json={"type": "sync", "programs": PROGRAMS})
    body = await resp.json()
    assert body["machines"]["wash"]["state"] == "idle"
    await hass.async_block_till_done()
    assert hass.states.get(select).attributes["options"] == ["Bunt 40°", "Handtücher 60°"]
    assert hass.states.get(collect).state == "unavailable", "frei → nichts abzuholen"

    await hass.services.async_call("select", "select_option", {"entity_id": select, "option": "Handtücher 60°"}, blocking=True)
    started = async_capture_events(hass, "wash_started")
    await hass.services.async_call("button", "press", {"entity_id": start}, blocking=True)
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "running"
    assert hass.states.get(_entity(hass, entry, "wash", "program")).state == "Handtücher 60°"
    assert int(hass.states.get(_entity(hass, entry, "wash", "remaining")).state) == 130
    assert len(started) == 1

    # Die App holt sich den Stand beim Abgleich
    body = await (await client.post(url, json={"type": "sync"})).json()
    assert body["machines"]["wash"]["state"] == "running"
    assert body["machines"]["wash"]["program"] == "Handtücher 60°"
    assert body["machines"]["wash"]["changed"]

    await hass.services.async_call("button", "press", {"entity_id": collect}, blocking=True)
    await hass.async_block_till_done()
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "idle"


async def test_aktionen_start_und_collect(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    url = f"/api/webhook/{entry.data['webhook_id']}"
    await client.post(url, json={"type": "sync", "programs": PROGRAMS})
    await hass.services.async_call(DOMAIN, "start", {"machine": "dry", "program": "2"}, blocking=True)
    assert hass.states.get(_entity(hass, entry, "dry", "program")).state == "Pflegeleicht"
    await hass.services.async_call(DOMAIN, "start", {"machine": "wash", "minutes": 30, "program": "Kurz"}, blocking=True)
    assert int(hass.states.get(_entity(hass, entry, "wash", "remaining")).state) == 30
    await hass.services.async_call(DOMAIN, "collect", {"machine": "dry"}, blocking=True)
    assert hass.states.get(_entity(hass, entry, "dry", "status")).state == "idle"
    with pytest.raises(Exception):
        await hass.services.async_call(DOMAIN, "start", {"machine": "dry", "program": "Gibt es nicht"}, blocking=True)


async def test_aeltere_meldung_der_app_wird_ignoriert(hass: HomeAssistant, client) -> None:
    entry, _ = await _setup(hass, client)
    url = f"/api/webhook/{entry.data['webhook_id']}"
    await client.post(url, json={"type": "sync", "programs": PROGRAMS})
    await hass.services.async_call(DOMAIN, "start", {"machine": "wash", "program": "1"}, blocking=True)
    # Handy war offline und meldet jetzt „frei“ mit altem Zeitstempel
    old = (dt_util.utcnow() - timedelta(minutes=10)).isoformat()
    body = await (await client.post(url, json={"type": "update", "machine": "wash", "state": "idle", "changed": old})).json()
    assert body["machines"]["wash"]["state"] == "running"
    assert hass.states.get(_entity(hass, entry, "wash", "status")).state == "running"
    # Neuere Meldung gewinnt
    body = await (await client.post(url, json={"type": "update", "machine": "wash", "state": "idle", "changed": dt_util.utcnow().isoformat()})).json()
    assert body["machines"]["wash"]["state"] == "idle"
