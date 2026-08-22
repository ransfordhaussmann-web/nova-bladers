# Creator Store Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.
Procedural fallbacks exist in `BeyModelBuilder.lua` when no model is present.

## Expected model names

| Bey | Studio model name |
|-----|-------------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Fang | `CrimsonFang` |
| Glacier Spin | `GlacierSpin` |

## Import priority

1. `Models/<studioModelName>` — cloned and scaled to arena size
2. `BeyCatalog.modelAssets.meshId` — optional Toolbox mesh
3. Procedural builder — always available as fallback

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`
