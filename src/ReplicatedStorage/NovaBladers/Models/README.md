# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here as **Model** instances.
Procedural fallback builds run when no matching model is found.

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `CrimsonFang` | Crimson Fang | Creator Store spinning top |
| `GlacierShield` | Glacier Shield | Creator Store spinning top |

## Studio setup

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Optional: set `meshId` in `BeyCatalog.lua` → `modelAssets.meshId`

After import: ReplicatedStorage → NovaBladers → Models → e.g. `CrimsonFang`
