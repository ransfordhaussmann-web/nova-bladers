# Bey Models — Studio Import Slots

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones them when `modelRef.studioModelName` matches the folder name.

| Folder Name | Bey | Creator Store Search |
|-------------|-----|----------------------|
| `NovaStriker` | Nova Striker | beyblade attack blue |
| `IronShell` | Iron Shell | beyblade defense metal |
| `VoltDash` | Volt Dash | spinning top yellow |
| `ShadowBite` | Shadow Bite | beyblade dark purple |
| `CrimsonVortex` | Crimson Vortex | beyblade red attack |
| `FrostCrown` | Frost Crown | beyblade ice blue |

## Import Steps

1. Roblox Studio → Toolbox → Creator Store → search term from table
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<FolderName>`
4. Set `PrimaryPart` on the collision part (or name it `Hull`)
5. Play — procedural layers are skipped when import is found

Without a Studio import, each bey uses its procedural 3D builder at runtime.

See `docs/BEY-MODELS.md` for meshId / `modelAssets` alternative.
