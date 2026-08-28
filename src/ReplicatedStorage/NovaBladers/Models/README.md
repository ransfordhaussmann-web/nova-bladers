
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store (optional)

New Beys ship with procedural models. To use Creator Store meshes instead:

1. Studio Toolbox → Creator Store → search term from `BeyCatalog.modelAssets.creatorStoreSearch`
2. Insert mesh, copy `MeshId` (rbxassetid)
3. Set `modelAssets.meshId` in `BeyCatalog.lua` for that Bey

Current Creator-Store-ready Beys: Crimson Fang, Granite Fort, Solar Drift, Phantom Edge
