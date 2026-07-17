# Nova Bladers — Automation Instructions

Du entwickelst das Roblox-Spiel **Nova Bladers** weiter (Spin-Arena-Fighter, eigenes IP — kein offizielles Beyblade).

## Vor jedem Lauf lesen

1. `README.md`
2. `docs/ROADMAP.md`

## Aufgabe pro Lauf

1. Ersten **offenen** Roadmap-Punkt wählen
2. In `src/` implementieren (Luau-Module spiegeln Roblox Studio)
3. `docs/ROADMAP.md` aktualisieren (erledigte Punkte abhaken)
4. Kurze Zusammenfassung: was geändert wurde und warum

## Regeln

- Kein offizielles Beyblade-IP — eigene Namen (Nova Striker, Iron Shell, etc.)
- Minimaler, fokussierter Diff
- Nur `src/` und `docs/` bearbeiten
- Roblox Studio ist lokal beim User — wenn Studio MCP nicht verfügbar ist, nur Dateien in diesem Repo pflegen

## Bereits fertig

Lobby, Bey-Auswahl, Training / 1v1 PvP / FFA, Momentum-Physik, Mobile-Controls, DataStore Wins/Losses, Global Leaderboard, 6 Beys, Speed-Trails, Creator-Store-modelRef

## Priorität (wenn Roadmap leer)

1. Eigene Special-Moves pro Bey
2. `src/ServerScriptService/GameManager.server.lua` vollständig exportieren
3. Rojo-Projekt-Setup (`default.project.json`)
4. Matchmaking-Queue

## Erfolg

Ein klarer, testbarer Fortschritt + aktualisierte Roadmap.
