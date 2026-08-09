
Import Creator Store / Sketchfab models here for in-game use.

## Studio-Pfad

`ReplicatedStorage → NovaBladers → Models → [ModelName]`

## Unterstützte Modelle

| ModelName | Bey | Quelle |
|-----------|-----|--------|
| NovaStriker | Nova Striker | Sketchfab (siehe docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell | Iron Shell | Creator Store |
| VoltDash | Volt Dash | Creator Store |
| ShadowBite | Shadow Bite | Creator Store |
| CrimsonFang | Crimson Fang | Creator Store |
| GraniteFort | Granite Fort | Creator Store |
| SolarDrift | Solar Drift | Creator Store |
| PhantomEdge | Phantom Edge | Creator Store |
| CrystalEdge | Crystal Edge | Creator Store |
| BlazeCrown | Blaze Crown | Creator Store |

## Import

1. Roblox Studio Toolbox → Creator Store → „spinning top“ suchen
2. Modell in `Models/` ablegen und nach `studioModelName` benennen
3. Alternativ: `modelAssets.meshId` in `BeyCatalog.lua` setzen

Ohne Import werden prozedurale 3D-Modelle aus `BeyModelBuilder.lua` verwendet.
