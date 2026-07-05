# Bey Models (Creator Store / Studio Import)

Optional 3D models for in-game Beys. Procedural fallbacks work without any imports.

## Studio path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Supported models

| ModelName     | Bey           | Notes                                      |
|---------------|---------------|--------------------------------------------|
| NovaStriker   | Nova Striker  | See `docs/SKETCHFAB-NOVA-STRIKER.md`       |
| CrystalDrift  | Crystal Drift | Ice/crystal spinning top from Creator Store |
| CrimsonFang   | Crimson Fang  | Fire/attack top from Creator Store          |

## Creator Store workflow

1. Roblox Studio → Toolbox → **Creator Store** → search e.g. "spinning top"
2. Insert model into `Models/` folder and rename to match `studioModelName` in `BeyCatalog.lua`
3. Or paste `rbxassetid` into `modelAssets.meshId` on the Bey entry

Models are auto-scaled to ~3.5 stud diameter and welded to the physics hull.
