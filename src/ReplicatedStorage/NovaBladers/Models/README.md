# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.

## Expected model names

| Bey | Studio folder name |
|-----|-------------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Fang | `CrimsonFang` |
| Granite Fort | `GraniteFort` |
| Solar Drift | `SolarDrift` |
| Phantom Edge | `PhantomEdge` |

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

`BeyModelBuilder` clones these models when present; otherwise it falls back to procedural 3D parts.

## Alternative: meshId in catalog

Set `modelAssets.meshId` in `BeyCatalog.lua` for a specific `rbxassetid://` mesh instead of a Studio model folder.
