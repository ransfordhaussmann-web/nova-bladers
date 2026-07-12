# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.

## Model names (must match `studioModelName` in BeyCatalog)

| Model Name    | Bey           | Notes                          |
|---------------|---------------|--------------------------------|
| NovaStriker   | Nova Striker  | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell     | Iron Shell    | Defense shell model            |
| VoltDash      | Volt Dash     | Flat stamina ring style        |
| ShadowBite    | Shadow Bite   | Dark balance type              |
| CrimsonForge  | Crimson Forge | Heavy attack / hammer style    |
| FrostPrism    | Frost Prism   | Crystal / ice defense style    |

## Studio path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Fallback

If no Studio model is found, `BeyModelBuilder` builds a procedural layered 3D model automatically.

Optional: set `modelAssets.meshId` in BeyCatalog to use a single MeshPart instead.
