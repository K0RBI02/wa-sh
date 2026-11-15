# wa:sh – Home Assistant

wa:sh bringt eine eigene Home-Assistant-Integration mit (`custom_components/wash`).
Die App meldet direkt an Home Assistant – ohne Zwischenserver, ohne Token.

## Installieren

**Über HACS:** HACS → ⋮ → *Benutzerdefinierte Repositories* →
`https://github.com/K0RBI02/wa-sh`, Typ *Integration* → **wa:sh** herunterladen →
Home Assistant neu starten.

**Von Hand:** Ordner `custom_components/wash` nach `/config/custom_components/wash`
kopieren, Home Assistant neu starten.

## Koppeln

1. Home Assistant → *Einstellungen → Geräte & Dienste → Integration hinzufügen* → **wa:sh** → Namen vergeben (z. B. „Waschküche“).
2. HA zeigt den **Kopplungscode** groß an (z. B. `K7Q-2M9`, 10 Min. gültig) und wartet.
   In der App: *Menü → Meine Programme → Home Assistant* → Adresse und Code eintragen → **Koppeln**.
3. Sobald das Handy gekoppelt ist, geht der Dialog in HA von selbst weiter – fertig.

Ein weiteres Handy koppelt man über **Konfigurieren** am Eintrag. Mit Nabu Casa
bekommt die App zusätzlich eine Cloud-Adresse und meldet auch, wenn sie das
Heimnetz nicht erreicht. Unter *⋮ → Diagnose herunterladen* gibt es den aktuellen
Stand (ohne Kopplungsdaten) für Fehlerberichte.

## Was in HA ankommt

Zwei Geräte – **Waschmaschine** und **Trockner** – mit je:

| Entität | Inhalt |
|---|---|
| Status | Frei · Läuft · Fertig |
| Läuft | Binärsensor, an solange die Maschine läuft |
| Fertig um | Zeitstempel |
| Restzeit | Minuten |
| Fortschritt | % |
| Programm | z. B. „Bunt 40°“ |

Die Integration rechnet das Ende selbst aus: Sie schaltet pünktlich auf „Fertig“,
auch wenn das Handy aus ist, und behält den Stand über HA-Neustarts.

Für Automationen gibt es außerdem die Ereignisse `wash_started`, `wash_finished`
und `wash_collected` (Daten: `machine`, `name`, `program`, `end`).

Beispiel – Durchsage und Licht, wenn die Wäsche fertig ist:

```yaml
automation:
  - alias: "Wäsche fertig – Durchsage"
    triggers:
      - trigger: event
        event_type: wash_finished
    actions:
      - action: tts.speak
        target:
          entity_id: tts.google_translate_de_de
        data:
          media_player_entity_id: media_player.wohnzimmer
          message: "{{ trigger.event.data.name }} ist fertig – ab in den Keller."
      - action: light.turn_on
        target:
          entity_id: light.flur
        data:
          flash: short
```

