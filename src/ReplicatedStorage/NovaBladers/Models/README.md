# Bey Studio Models

Import Creator Store or custom 3D models here for in-game use.

## Expected model names

| Bey | Folder name | Toolbox search hint |
|-----|-------------|---------------------|
| Nova Striker | `NovaStriker` | storm pegasus spinning top |
| Iron Shell | `IronShell` | spinning top metal defense shell |
| Volt Dash | `VoltDash` | spinning top lightning yellow stamina |
| Shadow Bite | `ShadowBite` | spinning top dark purple balance |
| Crimson Fang | `CrimsonFang` | spinning top red attack blade |
| Frost Ring | `FrostRing` | spinning top ice blue defense |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search hint from table above
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <FolderName>`
4. Optional: set `PrimaryPart`, name collision part `Hull`
5. Rojo sync or Play to test — procedural fallback used if model missing

Nova Striker also supports Sketchfab import — see `docs/SKETCHFAB-NOVA-STRIKER.md`
