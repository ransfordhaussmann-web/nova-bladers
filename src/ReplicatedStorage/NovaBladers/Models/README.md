# Bey Models — Studio Import

Place Creator Store or custom models here. `BeyModelBuilder` clones them when present.

| Folder name | Bey | Notes |
|-------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `CrimsonRipper` | Crimson Ripper | Creator Store spinning top |
| `FrostHalo` | Frost Halo | Creator Store spinning top |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <FolderName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — imported mesh replaces procedural fallback

If the folder is missing, procedural 3D layers are used instead.
