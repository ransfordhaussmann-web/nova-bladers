
Import Creator Store / Sketchfab models here for in-game use.

## Studio-Pfad

`ReplicatedStorage → NovaBladers → Models`

## Unterstützte Beys

| Model-Name   | Bey          | Fallback              |
|--------------|--------------|-----------------------|
| NovaStriker  | Nova Striker | Procedural Builder    |
| FrostCrown   | Frost Crown  | Procedural Builder    |
| CrimsonFang  | Crimson Fang | Procedural Builder    |

## Import (Studio)

1. Toolbox → Creator Store → Spinning-Top-Modell suchen
2. Modell in `Models` einfügen und wie in der Tabelle benennen
3. Alternativ: `meshId` in `BeyCatalog.lua` unter `modelAssets` eintragen

Ohne Import werden die Beys automatisch per `BeyModelBuilder.lua` gebaut.
