# Creator Store Bey Models

Optional 3D meshes from Roblox Creator Store. Procedural fallbacks work without imports.

## Import in Studio

1. Toolbox → Creator Store → search spinning top / arena fighter meshes
2. Place under `ReplicatedStorage → NovaBladers → Models`
3. Name models to match `modelRef.studioModelName` in `BeyCatalog.lua`

| Model Name   | Bey          | Type    |
|--------------|--------------|---------|
| NovaStriker  | Nova Striker | Attack  |
| FrostCrown   | Frost Crown  | Defense |
| CrimsonForge | Crimson Forge| Attack  |

After import, `BeyModelBuilder` auto-clones and scales to arena size (~3.5 studs).

## Without Studio models

All 6 Beys have procedural visuals in `BeyModelBuilder.lua`.
