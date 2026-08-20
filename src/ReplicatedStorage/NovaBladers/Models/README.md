# Creator Store Model Slots

Import optional 3D models from Roblox Creator Store into Studio, then place them here:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Model Name   | Bey          | Toolbox Hint                          |
|--------------|--------------|---------------------------------------|
| NovaStriker  | Nova Striker | Sketchfab GLB (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell    | Iron Shell   | Creator Store: defense bey / shell top |
| VoltDash     | Volt Dash    | Creator Store: stamina bey / speed top |
| ShadowBite   | Shadow Bite  | Creator Store: balance bey / dark top |
| BlazeDrift   | Blaze Drift  | Creator Store: spinning top / fire bey |
| FrostCrown   | Frost Crown  | Creator Store: ice bey / crystal top |

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D visuals.
Optional: set `modelAssets.meshId` in `BeyCatalog` for direct MeshPart asset IDs.
