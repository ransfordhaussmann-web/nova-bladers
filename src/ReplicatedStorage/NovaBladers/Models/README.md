# Creator Store / Studio Models

Import spinning-top models from Roblox Creator Store or Sketchfab into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Supported Beys

| studioModelName | Bey | Fallback |
|-----------------|-----|----------|
| NovaStriker | Nova Striker | Procedural attack blades |
| IronShell | Iron Shell | Procedural shell segments |
| VoltDash | Volt Dash | Procedural stamina ring |
| ShadowBite | Shadow Bite | Procedural fang blades |
| CrimsonFang | Crimson Fang | Procedural fang rush |
| GlacierSpin | Glacier Spin | Procedural ice crystals |

## Import Steps

1. Roblox Studio → Toolbox → Creator Store → search "spinning top"
2. Insert model into `ReplicatedStorage/NovaBladers/Models/`
3. Rename to match `studioModelName` from `BeyCatalog.modelRef`
4. Optional: set `modelAssets.meshId` in catalog for MeshPart fallback

Without a Studio model, `BeyModelBuilder` uses procedural geometry automatically.
