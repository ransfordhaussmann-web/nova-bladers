# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. Procedural fallback builds automatically when a model is missing.

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Toolbox / Creator Store spinning top |
| `VoltDash` | Volt Dash | Toolbox / Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Toolbox / Creator Store spinning top |
| `CrimsonFang` | Crimson Fang | Toolbox / Creator Store spinning top |
| `GlacierCrown` | Glacier Crown | Toolbox / Creator Store spinning top |

## Import steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into `ReplicatedStorage → NovaBladers → Models`
4. Rename to match `studioModelName` in `BeyCatalog.lua`
5. Set `PrimaryPart` on the hull; optional child named `Hull` for welding

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a full Studio model.
