# Bey Models (Creator Store / Studio Import)

Import spinning-top meshes from the Roblox Creator Store into Studio, then place them here under `ReplicatedStorage → NovaBladers → Models`.

## Expected model names

| Catalog ID    | Studio model name |
|---------------|-------------------|
| NovaStriker   | NovaStriker       |
| IronShell     | IronShell         |
| VoltDash      | VoltDash          |
| ShadowBite    | ShadowBite        |
| CrimsonFang   | CrimsonFang       |
| GlacierSpin   | GlacierSpin       |

## How to import

1. Roblox Studio → Toolbox → **Creator Store** → search "spinning top" (no official IP assets)
2. Insert mesh into `ReplicatedStorage/NovaBladers/Models/`
3. Rename the Model to match `studioModelName` in `BeyCatalog.lua`
4. Optional: set `modelAssets.meshId` in the catalog for direct MeshPart loading

Without a Studio model, `BeyModelBuilder` falls back to procedural geometry.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for the optional Sketchfab GLB import.
