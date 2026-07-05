
Import optional Creator Store / Sketchfab models here for in-game use.

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrimsonFang` | Crimson Fang | Creator Store spin-top → `ReplicatedStorage/NovaBladers/Models/CrimsonFang` |
| `FrostHalo` | Frost Halo | Creator Store spin-top → `ReplicatedStorage/NovaBladers/Models/FrostHalo` |

After Studio import: set `PrimaryPart`, weld mesh parts, optional `Hull` collider.
Procedural fallback models are used when the folder is missing.

Optional: paste `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a folder.
