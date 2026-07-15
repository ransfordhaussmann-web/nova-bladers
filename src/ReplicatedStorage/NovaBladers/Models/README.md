
Import Creator Store or custom 3D models here for in-game use.

## Studio model folders

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

Each folder name matches `modelRef.studioModelName` in `BeyCatalog.lua`.

## Import steps

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<Name>`
4. Set `PrimaryPart` (or name collision part `Hull`)

If no Studio model exists, procedural layers from `BeyModelBuilder.lua` are used automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import.

See `docs/BEY-MODELS.md` for full setup guide.
