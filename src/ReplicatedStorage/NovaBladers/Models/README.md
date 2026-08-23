# Nova Bladers — Creator Store Model Imports

Optional 3D models from Roblox Creator Store / Toolbox for in-game Beys.

## Import in Studio

1. Roblox Studio → Toolbox → Creator Store → search "spinning top" / "beyblade"
2. Import model into `ReplicatedStorage → NovaBladers → Models`
3. Name the model folder to match `BeyCatalog.modelRef.studioModelName`

## Supported Models

| Bey | Studio Model Name | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | Sketchfab Storm Pegasus ref |
| Crimson Vortex | `CrimsonVortex` | Red attack-type spinning top |
| Glacier Mantle | `GlacierMantle` | Ice/defense-type spinning top |

If no Studio model is found, procedural builders in `BeyModelBuilder.lua` are used automatically.

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from Creator Store uploads.
