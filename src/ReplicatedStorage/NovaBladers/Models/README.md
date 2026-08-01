# Bey Studio Models

Import Creator Store or custom 3D models into Roblox Studio under:

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model Name | Bey | Notes |
|------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | Iron Shell | Creator Store spinning top |
| VoltDash | Volt Dash | Creator Store spinning top |
| ShadowBite | Shadow Bite | Creator Store spinning top |
| CrimsonFang | Crimson Fang | Creator Store spinning top |
| FrostRing | Frost Ring | Creator Store spinning top |

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D layers.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing to Models/.
