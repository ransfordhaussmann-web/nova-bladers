
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store (optional)

Each Bey in `BeyCatalog.lua` can set `modelAssets.meshId` (rbxassetid) or
`modelAssets.creatorStoreSearch` as a Toolbox hint. Procedural models are used
when no external mesh is configured.
