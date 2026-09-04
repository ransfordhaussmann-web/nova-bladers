# Nova Bladers — Studio Model Imports

Place imported Creator Store / custom 3D models under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

The game clones these at runtime when present; otherwise it falls back to procedural models from `BeyModelBuilder.lua`.

## Model names

| Bey | `studioModelName` | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | Sketchfab import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Iron Shell | `IronShell` | Creator Store spinning top |
| Volt Dash | `VoltDash` | Creator Store spinning top |
| Shadow Bite | `ShadowBite` | Creator Store spinning top |
| Crimson Fang | `CrimsonFang` | Creator Store spinning top |
| Granite Fort | `GraniteFort` | Creator Store spinning top |
| Solar Drift | `SolarDrift` | Creator Store spinning top |
| Phantom Edge | `PhantomEdge` | Creator Store spinning top |
| Crystal Edge | `CrystalEdge` | Creator Store spinning top |
| Blaze Crown | `BlazeCrown` | Creator Store spinning top |

## Import checklist

1. Toolbox → Creator Store → search `spinning top` (avoid official Beyblade IP names)
2. Scale to ~3.5 studs wide, flat on arena floor
3. Rename model to the `studioModelName` from the table
4. Move to `ReplicatedStorage/NovaBladers/Models/`
5. Set `PrimaryPart` or child part named `Hull`
6. Play — `BeyModelBuilder` auto-clones and welds to physics hull

Optional: save as `.rbxmx` in repo for Rojo sync.
