# Bey Studio Models

Import Creator Store or custom 3D models into Studio under:

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell | Optional Creator Store mesh |
| `VoltDash` | Volt Dash | Optional Creator Store mesh |
| `ShadowBite` | Shadow Bite | Optional Creator Store mesh |
| `CrimsonFang` | Crimson Fang | Optional Creator Store mesh |
| `FrostRing` | Frost Ring | Optional Creator Store mesh |

## Setup

1. Insert model from Creator Store (Toolbox → search `spinning top`)
2. Rename to match `studioModelName` in `BeyCatalog.lua`
3. Move to `ReplicatedStorage/NovaBladers/Models/`
4. Set `PrimaryPart` or name collision part `Hull`
5. Target size ~3.5 studs diameter (auto-scaled at runtime)

If no Studio model is found, `BeyModelBuilder` uses procedural 3D layers.

## Alternative: meshId

Paste a `rbxassetid://` into `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a full model.
