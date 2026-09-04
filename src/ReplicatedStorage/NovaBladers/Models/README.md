# Bey Models — Studio Import

Import Creator Store or custom 3D models into Roblox Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

Procedural fallback models are used when no Studio model is found.

## All Beys (10)

| Bey ID | studioModelName | Type |
|--------|-----------------|------|
| Nova Striker | `NovaStriker` | Attack |
| Iron Shell | `IronShell` | Defense |
| Volt Dash | `VoltDash` | Stamina |
| Shadow Bite | `ShadowBite` | Balance |
| Crimson Fang | `CrimsonFang` | Attack |
| Granite Fort | `GraniteFort` | Defense |
| Solar Drift | `SolarDrift` | Stamina |
| Phantom Edge | `PhantomEdge` | Balance |
| Crystal Edge | `CrystalEdge` | Attack |
| Blaze Crown | `BlazeCrown` | Balance |

## Import Steps

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — `BeyModelBuilder` auto-clones and scales via `modelRef.studioModelName`

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
