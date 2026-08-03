# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Model Name   | Bey           | Notes                          |
|--------------|---------------|--------------------------------|
| NovaStriker  | Nova Striker  | Sketchfab GLB import supported |
| IronShell    | Iron Shell    |                                |
| VoltDash     | Volt Dash     |                                |
| ShadowBite   | Shadow Bite   |                                |
| CrimsonFang  | Crimson Fang  |                                |
| FrostRing    | Frost Ring    |                                |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Without a Studio model, procedural fallback meshes are built automatically by `BeyModelBuilder`.
Optional: set `modelAssets.meshId` in the catalog for direct Toolbox mesh IDs.
