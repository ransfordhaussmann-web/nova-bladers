# Creator Store / Studio Models

Import 3D models from Roblox Creator Store or Blender into Studio under this folder.

## Expected model names

| Bey | Studio folder name |
|-----|-------------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Blaze Drift | `BlazeDrift` |
| Frost Crown | `FrostCrown` |

## How to import

1. Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, resize to ~3–4 studs wide
4. Move to `ReplicatedStorage → NovaBladers → Models → <Name>`
5. Set `PrimaryPart`, name collision part `Hull`, weld parts

If no Studio model exists, `BeyModelBuilder` falls back to procedural 3D layers.

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full model folder.

See `docs/BEY-MODELS.md` for full setup guide.
