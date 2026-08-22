# Creator Store / Studio Models

Import Creator Store or custom 3D models into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName | Notes |
|-----|-----------------|-------|
| Nova Striker | `NovaStriker` | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Iron Shell | `IronShell` | Procedural fallback if missing |
| Volt Dash | `VoltDash` | Procedural fallback if missing |
| Shadow Bite | `ShadowBite` | Procedural fallback if missing |
| Crimson Vortex | `CrimsonVortex` | Procedural fallback if missing |
| Glacier Mantle | `GlacierMantle` | Procedural fallback if missing |

## Studio import steps

1. Toolbox → Creator Store → search `spinning top` (avoid Beyblade IP names)
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` on the collision hull; name it `Hull` if possible
5. Play — `BeyModelBuilder` clones the model when present, otherwise uses procedural layers

Optional: adjust `targetSize` or `importRotation` in `BeyCatalog.lua` per bey.
