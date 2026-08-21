# Creator Store Bey Models

Import 3D models from Roblox Studio Toolbox → **Creator Store** into this folder.

## Expected model names

| Bey | Studio model name | Fallback |
|-----|-------------------|----------|
| Nova Striker | `NovaStriker` | Procedural + Sketchfab GLB (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| Iron Shell | `IronShell` | Procedural |
| Volt Dash | `VoltDash` | Procedural |
| Shadow Bite | `ShadowBite` | Procedural |
| Blaze Drift | `BlazeDrift` | Procedural |
| Frost Crown | `FrostCrown` | Procedural |

After import in Studio: `ReplicatedStorage → NovaBladers → Models → <Name>`

`BeyModelBuilder` clones these models when present; otherwise it builds procedural layered meshes.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart asset IDs.
