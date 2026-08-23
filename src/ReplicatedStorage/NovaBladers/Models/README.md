# Creator Store Model Imports

Optional 3D meshes from Roblox Creator Store. Procedural fallbacks exist if no model is present.

## Import in Studio

1. Toolbox → Creator Store → search "spinning top" / "beyblade" (no official IP names in-game)
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to match `studioModelName` in `BeyCatalog.lua`

| Model Name     | Bey            | Catalog ID      |
|----------------|----------------|-----------------|
| NovaStriker    | Nova Striker   | NovaStriker     |
| CrimsonVortex  | Crimson Vortex | CrimsonVortex   |
| GlacierMantle  | Glacier Mantle | GlacierMantle   |

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import steps.

After Studio import: `ReplicatedStorage → NovaBladers → Models → NovaStriker`

## meshId Alternative

Set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from Creator Store uploads.
