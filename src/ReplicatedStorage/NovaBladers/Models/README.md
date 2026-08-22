# Creator Store Models

Optional 3D models from Roblox Creator Store / Sketchfab import.
Place each model under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`.

When a Studio model exists, `BeyModelBuilder` clones it instead of the procedural fallback.

| Bey | studioModelName | Notes |
|-----|-----------------|-------|
| Nova Striker | `NovaStriker` | See docs/SKETCHFAB-NOVA-STRIKER.md |
| Iron Shell | `IronShell` | Toolbox: spinning top / defense shell |
| Volt Dash | `VoltDash` | Toolbox: flat stamina ring style |
| Shadow Bite | `ShadowBite` | Toolbox: dark balance top |
| Crimson Vortex | `CrimsonVortex` | Toolbox: attack spiral top |
| Glacier Mantle | `GlacierMantle` | Toolbox: ice / crystal defense top |

## Studio setup

1. Creator Store → search `spinning top` (avoid UGC waist accessories)
2. Insert model into `ReplicatedStorage/NovaBladers/Models/`
3. Rename to match `studioModelName` in `BeyCatalog.lua`
4. Set `PrimaryPart` or name collision part `Hull`
5. Rojo sync → Play to test

Scale is auto-fitted via `modelRef.targetSize` in the catalog.
