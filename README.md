# Nova Bladers

Anime-inspirierter Spin-Arena-Fighter für Roblox (eigenes IP, kein offizielles Beyblade).

## Projektstruktur

- `src/` — Luau-Script-Spiegel aus Roblox Studio (für Git + Automation)
- `docs/ROADMAP.md` — geplante Features

## Spielmodi

| Spieler | Modus |
|---------|-------|
| 1 | Training vs. Dummy |
| 2 | 1v1 PvP |
| 3+ | FFA (Free-for-All) |

## Beys

Nova Striker, Iron Shell, Volt Dash, Shadow Bite, Crimson Flare, Frost Crown

## Setup

### PC (Windows) — Cursor + Roblox Studio

**Erstes Mal auf dem Laptop:**

1. Doppelklick **`setup-pc.bat`** (prüft Git, Node, Rojo)
2. Anleitung: **[docs/SETUP-WINDOWS.md](docs/SETUP-WINDOWS.md)**

**Täglich:**

1. **`start-rojo.bat`** starten
2. Roblox Studio → Plugins → Rojo → Connect
3. In Cursor `src/` bearbeiten → in Studio Play testen

### Roblox Studio (manuell ohne Rojo)

1. Roblox Studio: Place mit Arena + BeyTemplates öffnen
2. Scripts aus `src/` in Studio übernehmen (oder direkt in Studio bearbeiten)
3. Spiel veröffentlichen + API Services aktivieren (DataStore)

## Git (für Automation)

Git ist auf diesem PC noch nicht installiert. Für Cursor Automations:

1. [Git für Windows](https://git-scm.com/download/win) installieren
2. Repo auf GitHub pushen
3. In der Automation das GitHub-Repo verknüpfen

## Controls

- WASD / Joystick — Bewegen
- Shift — Charge
- Space — Jump (aus der Bowl) / Dive (zurück in die Arena)
- C — RPM / Spin wiederherstellen
- Q — Dodge
- E — Special (wenn Energy voll)
- R — Restart
