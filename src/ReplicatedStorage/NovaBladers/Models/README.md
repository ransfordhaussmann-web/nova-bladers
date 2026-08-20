
Import Creator Store or custom 3D models here for in-game use.

## Folder names (match `modelRef.studioModelName` in BeyCatalog)

| Bey | Folder |
|-----|--------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Blaze Drift | `BlazeDrift` |
| Frost Crown | `FrostCrown` |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <Name>`

If no model is present, `BeyModelBuilder` builds a procedural 3D fallback at runtime.

Optional: set `modelAssets.meshId` in BeyCatalog for a single MeshPart instead of a full model.
