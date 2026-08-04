# Bey Model Imports

Import Creator Store / Sketchfab models here for in-game use.

## Model slots (ReplicatedStorage → NovaBladers → Models)

| Model Name | Bey | Notes |
|------------|-----|-------|
| **NovaStriker** | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| **IronShell** | Iron Shell | Creator Store defense top |
| **VoltDash** | Volt Dash | Creator Store stamina top |
| **ShadowBite** | Shadow Bite | Creator Store balance top |
| **CrimsonForge** | Crimson Forge | Creator Store forge / attack top |
| **FrostPrism** | Frost Prism | Creator Store crystal top |
| **BlazeCyclone** | Blaze Cyclone | Creator Store mesh or `modelAssets.meshId` |
| **GlacierCore** | Glacier Core | Creator Store mesh or custom import |

## Studio import

1. Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` or name collision part `Hull`

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (see docs/BEY-MODELS.md).

Procedural layers are used automatically when no Studio model is present.
