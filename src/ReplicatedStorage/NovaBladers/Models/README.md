# Bey model import folders

Place Creator Store or custom 3D models here for in-game use.

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | Defense shell mesh |
| `VoltDash` | Volt Dash | Flat stamina ring style |
| `ShadowBite` | Shadow Bite | Dark balance type |
| `CrimsonEdge` | Crimson Edge | Attack flame blades |
| `FrostCore` | Frost Core | Ice defense shell |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <FolderName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Procedural layers are used when no model folder is present.
