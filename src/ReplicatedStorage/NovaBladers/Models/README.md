# Bey Models (optional Creator Store imports)

Procedural builders in `BeyModelBuilder.lua` work without any imports.
For higher-quality meshes, import models into Studio under this folder.

## Studio path

`ReplicatedStorage` → `NovaBladers` → `Models` → `<ModelName>`

## Supported model names

| Model folder   | Bey          | Catalog `modelRef.studioModelName` |
|----------------|--------------|------------------------------------|
| NovaStriker    | Nova Striker | NovaStriker                        |
| FrostCrown     | Frost Crown  | FrostCrown                         |
| CrimsonFang    | Crimson Fang | CrimsonFang                        |

## Alternative: rbxassetid mesh

Set `modelAssets.meshId` in `BeyCatalog.lua` (Toolbox → Creator Store → copy asset id).

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.

After Studio import: `ReplicatedStorage` → `NovaBladers` → `Models` → `NovaStriker`
