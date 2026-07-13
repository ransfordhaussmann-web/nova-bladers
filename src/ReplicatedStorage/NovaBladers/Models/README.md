
Import Creator Store / Sketchfab models here for in-game use.

| Bey | Folder name | Notes |
|-----|-------------|-------|
| Nova Striker | `NovaStriker` | See docs/SKETCHFAB-NOVA-STRIKER.md |
| Iron Shell | `IronShell` | Creator Store spinning top |
| Crimson Edge | `CrimsonEdge` | Creator Store attack bey |
| Frost Halo | `FrostHalo` | Creator Store defense bey |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<FolderName>`

Procedural fallback builds automatically when no model folder exists.
Optional: set `modelAssets.meshId` in BeyCatalog.lua instead of a full model import.
