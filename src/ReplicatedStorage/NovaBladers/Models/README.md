# Creator Store Bey Models

Import Creator Store or custom models here for in-game use.
Procedural fallbacks in `BeyModelBuilder` work without any imports.

## Studio path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Supported models

| ModelName   | Bey          | Notes |
|-------------|--------------|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell   | Iron Shell   | Creator Store import |
| VoltDash    | Volt Dash    | Creator Store import |
| ShadowBite  | Shadow Bite  | Creator Store import |
| CrimsonFang | Crimson Fang | Creator Store import |
| FrostCrown  | Frost Crown  | Creator Store import |
| SolarCoil   | Solar Coil   | Creator Store import |

## Optional mesh IDs

Set `modelAssets.meshId` in `BeyCatalog.lua` to use a Creator Store mesh without a Studio model folder.

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade" (use only as visual reference — own IP names in catalog).
