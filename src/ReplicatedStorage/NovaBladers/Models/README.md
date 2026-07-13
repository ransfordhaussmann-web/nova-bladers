Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store slots (optional)

Import models from Toolbox (Creator Store → search `spinning top` / `bey`) and place under `Models/`, or set `modelAssets.meshId` in `BeyCatalog.lua`:

| Bey | Studio model name | Catalog field |
|-----|-------------------|---------------|
| Nova Striker | NovaStriker | `modelRef.studioModelName` |
| Crimson Blaze | CrimsonBlaze | `modelRef` + `modelAssets.meshId` |
| Frost Crown | FrostCrown | `modelRef` + `modelAssets.meshId` |

Procedural fallback builds are used when no mesh is configured.
