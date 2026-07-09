# Bey Model Imports

Optional Creator Store / custom 3D models for in-game use.

## Studio placement

After import, place models here:

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonEdge` | Crimson Edge |
| `FrostHalo` | Frost Halo |

Path: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## How it works

1. `BeyModelBuilder` tries to clone from this folder first (`modelRef.studioModelName`)
2. Falls back to `modelAssets.meshId` from Creator Store Toolbox
3. Falls back to procedural layered 3D build

## Creator Store search hints

See `modelRef.toolboxSearch` in `BeyCatalog.lua` for suggested Toolbox queries.
