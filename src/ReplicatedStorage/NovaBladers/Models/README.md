# Bey Model Import Folders

Place Creator Store or imported 3D models here. Each folder name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Folder | Bey |
|--------|-----|
| `NovaStriker` | Nova Striker (Sketchfab GLB — see `tools/nova-striker-import/`) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonEdge` | Crimson Edge |
| `FrostCore` | Frost Core |

After Studio import: set `PrimaryPart`, name collision part `Hull`. Procedural layers are skipped when a model is found.
