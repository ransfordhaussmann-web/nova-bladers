# Bey Model Imports (Studio)

Place imported Creator Store or FBX models here for in-game use.

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonEdge` | Crimson Edge | Creator Store spin top → `ReplicatedStorage/NovaBladers/Models/CrimsonEdge` |
| `FrostHalo` | Frost Halo | Creator Store spin top → `ReplicatedStorage/NovaBladers/Models/FrostHalo` |

After Studio import: set `PrimaryPart`, name collision part `Hull`, weld mesh parts.

Without import: procedural builders in `BeyModelBuilder.lua` are used automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a folder import.
