# Creator Store / imported 3D models

Place optional Studio-imported spin-top models here. Each bey in `BeyCatalog.lua` can reference a model via `modelRef.studioModelName`.

| Model folder name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonVortex` | Crimson Vortex |
| `GlacierMantle` | Glacier Mantle |

## How to import

1. Roblox Studio → Toolbox → Creator Store (search: spinning top, arena fighter)
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set `PrimaryPart` or name collision part `Hull`

If no model is present, `BeyModelBuilder` builds a procedural layered mesh automatically.
