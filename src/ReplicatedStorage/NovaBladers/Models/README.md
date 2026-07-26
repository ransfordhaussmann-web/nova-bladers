
Import Creator Store or custom 3D models here for in-game use.

## Studio placement

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model folder | Bey | Notes |
|--------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `CrimsonFang` | Crimson Fang | Creator Store spinning top |
| `FrostCore` | Frost Core | Creator Store spinning top |

## Import steps (Creator Store)

1. Roblox Studio → Toolbox → Creator Store
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
5. Set `PrimaryPart` or name collision part `Hull`
6. Play — `BeyModelBuilder` clones the model; procedural fallback if missing

## Import steps (custom FBX/GLB)

1. File → Import 3D → place under the matching folder name
2. Adjust `targetSize` in `BeyCatalog.modelRef` if needed
