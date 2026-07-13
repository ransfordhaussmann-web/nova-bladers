Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store slots (optional)

Set `modelAssets.meshId` in `BeyCatalog.lua` after importing from Toolbox:

| Bey | Studio model name | Catalog field |
|-----|-------------------|---------------|
| Nova Striker | NovaStriker | `modelRef.studioModelName` |
| Crimson Blaze | CrimsonBlaze | `modelAssets.meshId` |
| Frost Crown | FrostCrown | `modelAssets.meshId` |

Procedural fallback builds are used when no mesh is configured.
