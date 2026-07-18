# Bey 3D Models (Studio Import)

Prozedurale Fallback-Modelle werden automatisch gebaut, wenn kein Studio-Modell vorhanden ist.

## Import in Roblox Studio

1. Creator Store / Toolbox: Spin-Top-Modell suchen (eigenes IP — keine offiziellen Marken)
2. Modell unter `ReplicatedStorage → NovaBladers → Models` ablegen
3. Exakter Name muss `studioModelName` in `BeyCatalog.lua` entsprechen

| Bey | Studio-Modellname | Optional meshId |
|-----|-------------------|-----------------|
| Nova Striker | `NovaStriker` | Sketchfab GLB — siehe `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Crimson Fang | `CrimsonFang` | `modelAssets.meshId` in BeyCatalog |
| Frost Halo | `FrostHalo` | `modelAssets.meshId` in BeyCatalog |

## Priorität (BeyModelBuilder)

1. `Models/` Ordner (`modelRef.studioModelName`)
2. `modelAssets.meshId` (Creator Store Asset)
3. Prozedurales Fallback pro Bey-ID
