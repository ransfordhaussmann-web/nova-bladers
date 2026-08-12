
Import Creator Store or custom 3D models here for in-game use.

## Studio-Pfad

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Alle 8 Beys

| Bey | studioModelName | modelRef in BeyCatalog |
|-----|-----------------|------------------------|
| Nova Striker | NovaStriker | sketchfab + Studio |
| Iron Shell | IronShell | searchTerms |
| Volt Dash | VoltDash | searchTerms |
| Shadow Bite | ShadowBite | searchTerms |
| Starfall Edge | StarfallEdge | searchTerms |
| Stone Halo | StoneHalo | searchTerms |
| Thunder Coil | ThunderCoil | searchTerms |
| Night Maw | NightMaw | searchTerms |

## Import (Creator Store)

1. Studio → Toolbox → Creator Store → nach `searchTerms` aus BeyCatalog suchen
2. Modell einfügen, auf ~3.5 Studs Breite skalieren, flach auf den Boden legen
3. Nach `Models/<studioModelName>` verschieben, PrimaryPart setzen
4. Optional: `modelAssets.meshId` in BeyCatalog für direkte MeshId-Nutzung

## Nova Striker (Sketchfab)

Siehe `docs/SKETCHFAB-NOVA-STRIKER.md` — GLB als **NovaStriker** importieren.

Ohne importiertes Modell nutzt das Spiel die prozeduralen 3D-Layer aus `BeyModelBuilder.lua`.
