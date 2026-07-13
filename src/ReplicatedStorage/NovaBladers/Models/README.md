# Bey Models (Studio import slots)

Place Creator Store or custom spin-top models here. `BeyModelBuilder` clones by `studioModelName` from `BeyCatalog.modelRef`.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonBlaze` | Crimson Blaze |
| `FrostCrown` | Frost Crown |

## How to import

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/<Name>`
4. Set `PrimaryPart` (or name collision part `Hull`)

Procedural layers are used when no Studio model is present. Optional: paste `meshId` into `BeyCatalog.modelAssets` for a single MeshPart.

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker reference).
