# Bey Studio Models

Import Creator Store or custom models into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName | Notes |
|-----|-----------------|-------|
| Nova Striker | NovaStriker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| Iron Shell | IronShell | Toolbox → Creator Store → "spinning top" |
| Volt Dash | VoltDash | Optional `modelAssets.meshId` in BeyCatalog |
| Shadow Bite | ShadowBite | Optional `modelAssets.meshId` in BeyCatalog |
| Crimson Fang | CrimsonFang | Optional `modelAssets.meshId` in BeyCatalog |
| Frost Crown | FrostCrown | Optional `modelAssets.meshId` in BeyCatalog |
| Solar Coil | SolarCoil | Optional `modelAssets.meshId` in BeyCatalog |

Procedural fallback in `BeyModelBuilder` when no Studio/Store model is present.

To use a Creator Store mesh without a full model:
1. Studio Toolbox → Creator Store → search "spinning top"
2. Copy `rbxassetid://…` into `BeyCatalog.modelAssets.meshId`
