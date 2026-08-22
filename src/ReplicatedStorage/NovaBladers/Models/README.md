
Import Creator Store or custom 3D models here for in-game use.

## Folder names (must match `BeyCatalog.modelRef.studioModelName`)

| Bey | Folder name |
|-----|-------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Vortex | `CrimsonVortex` |
| Glacier Mantle | `GlacierMantle` |

## How to import

1. Roblox Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, optional `Hull` part for collision weld
5. Play — `BeyModelBuilder` clones the model when the folder exists

Without a Studio model, procedural 3D layers are built automatically.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
