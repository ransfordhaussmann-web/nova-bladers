
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store (optional)

Procedural models ship by default. To swap in Toolbox meshes, set `modelAssets.meshId`
in `BeyCatalog.lua` (rbxassetid) after searching Creator Store with each Bey's
`modelAssets.creatorStoreSearch` hint (e.g. "spinning top red attack" for Crimson Fang).
