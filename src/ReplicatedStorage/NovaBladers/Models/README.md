# Nova Bladers — Creator Store Model Hooks

Import spinning-top models from Roblox Studio **Toolbox → Creator Store** into this folder.
Procedural fallbacks render automatically when no Studio model is present.

## Import steps (Studio)

1. Open Toolbox → Creator Store, search for "spinning top" or "beyblade" (generic assets only).
2. Insert the model into `ReplicatedStorage → NovaBladers → Models`.
3. Rename to match `studioModelName` in `BeyCatalog.lua`.
4. Set a `PrimaryPart` (or a child named `Hull`) for weld anchoring.
5. Play-test — `BeyModelBuilder` scales to ~3.5 stud diameter automatically.

## Expected model names

| Bey | Folder name | Catalog entry |
|-----|-------------|---------------|
| Nova Striker | `NovaStriker` | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Iron Shell | `IronShell` | `modelRef.studioModelName` |
| Crimson Fang | `CrimsonFang` | `modelRef.studioModelName` |
| Frost Core | `FrostCore` | `modelRef.studioModelName` |

Volt Dash and Shadow Bite use procedural geometry only (no Creator Store hook).

## Tuning

- **Too big/small:** set `modelRef.targetSize` in `BeyCatalog.lua` (default 3.5).
- **Wrong orientation:** set `modelRef.importRotation` (default lays model flat: `-90°` on X).
