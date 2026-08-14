# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store.

Place imported models under `ReplicatedStorage → NovaBladers → Models` using the `studioModelName` from `BeyCatalog.modelRef`.

| Bey | Studio folder | Toolbox search hint |
|-----|---------------|---------------------|
| Nova Striker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Crimson Fang | `CrimsonFang` | `spinning top red attack` |
| Frost Crown | `FrostCrown` | `spinning top ice defense` |

If no model folder exists, `BeyModelBuilder` falls back to procedural geometry.

Optional: set `modelAssets.meshId` in `BeyCatalog` for a single MeshPart import instead of a full model folder.
