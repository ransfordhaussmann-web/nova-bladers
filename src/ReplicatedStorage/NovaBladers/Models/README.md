# Bey Studio Models

Import Creator Store / Sketchfab models here as Roblox `Model` instances.

| Model name   | Bey          | Notes |
|--------------|--------------|-------|
| NovaStriker  | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| IronShell    | Iron Shell   | Toolbox import optional |
| VoltDash     | Volt Dash    | Toolbox import optional |
| ShadowBite   | Shadow Bite  | Toolbox import optional |
| CrimsonFang  | Crimson Fang | Toolbox import optional |
| FrostCrown   | Frost Crown  | Toolbox import optional |

Path after import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` (already configured).
Optional: paste Toolbox `meshId` into `modelAssets.meshId` for mesh-only imports.

Without Studio models, procedural builders in `BeyModelBuilder.lua` are used automatically.
