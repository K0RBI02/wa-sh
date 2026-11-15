# wa:sh – Home Assistant

wa:sh ships its own Home Assistant integration (`custom_components/wash`).
The app reports straight to Home Assistant – no relay server, no token.

## Install

**Via HACS:** HACS → ⋮ → *Custom repositories* →
`https://github.com/K0RBI02/wa-sh`, type *Integration* → download **wa:sh** →
restart Home Assistant.

**Manually:** copy the folder `custom_components/wash` to `/config/custom_components/wash`,
restart Home Assistant.

## Pair

1. Home Assistant → *Settings → Devices & services → Add integration* → **wa:sh** → choose a name (e.g. “Laundry room”).
2. Home Assistant shows the **pairing code** in large type (e.g. `K7Q-2M9`, valid for 10 minutes) and waits.
   In the app: *Menu → My programs → Home Assistant* → enter address and code → **Pair**.
3. As soon as the phone is paired, the dialog in Home Assistant continues on its own – done.

Pair another phone via **Configure** on the entry. With Nabu Casa the app also gets
a cloud address and keeps reporting when it can't reach your home network.
*⋮ → Download diagnostics* gives you the current state (without pairing data) for
bug reports.

## What shows up in Home Assistant

Two devices – **Washer** (*Waschmaschine*) and **Dryer** (*Trockner*) – each with:

| Entity | Content |
|---|---|
| Status | Idle · Running · Finished |
| Running | Binary sensor, on while the machine runs |
| Finishes at | Timestamp |
| Time remaining | Minutes |
| Progress | % |
| Program | e.g. “Bunt 40°” |

The integration works out the end time itself: it switches to “Finished” on time,
even if the phone is off, and keeps its state across Home Assistant restarts.

For automations there are also the events `wash_started`, `wash_finished`
and `wash_collected` (data: `machine`, `name`, `program`, `end`).

Example – announcement and a light flash when the laundry is done:

```yaml
automation:
  - alias: "Laundry done – announcement"
    triggers:
      - trigger: event
        event_type: wash_finished
    actions:
      - action: tts.speak
        target:
          entity_id: tts.google_translate_en_com
        data:
          media_player_entity_id: media_player.living_room
          message: "The {{ trigger.event.data.machine == 'wash' and 'washer' or 'dryer' }} is done – down to the basement."
      - action: light.turn_on
        target:
          entity_id: light.hallway
        data:
          flash: short
```

## How it works

- The app sends a small JSON message to a webhook of the integration whenever
  something changes (start, “already done”, collected). Pairing hands the app that
  webhook – the code is single-use, valid for 10 minutes, and failed attempts are rate-limited.
- Home Assistant stores the last state and schedules “finished” itself.
- Tests run against a real Home Assistant: `pip install pytest-homeassistant-custom-component && python -m pytest`.
