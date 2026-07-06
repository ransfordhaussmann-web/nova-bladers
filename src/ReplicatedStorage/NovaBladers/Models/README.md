# Bey Models (Creator Store / Studio Import)

Procedural Fallbacks existieren für alle Beys. Optional können Creator-Store-Modelle importiert werden:

| Studio-Name   | Bey           | Typ     |
|---------------|---------------|---------|
| NovaStriker   | Nova Striker  | Attack  |
| IronShell     | Iron Shell    | Defense |
| VoltDash      | Volt Dash     | Stamina |
| ShadowBite    | Shadow Bite   | Balance |
| CrimsonBlaze  | Crimson Blaze | Attack  |
| FrostOrbit    | Frost Orbit   | Defense |

## Import in Studio

1. Toolbox → Creator Store → „spinning top“ / „bey“ suchen
2. Model unter `ReplicatedStorage → NovaBladers → Models` ablegen (Name wie oben)
3. Optional: `modelAssets.meshId` in `BeyCatalog.lua` eintragen

Nach Rojo-Sync werden importierte Modelle automatisch skaliert und ans Physics-Hull geschweißt.
