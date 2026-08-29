
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store Beys (optional mesh import)

Procedural models are built automatically. To use Creator Store meshes:

1. Toolbox → Creator Store → search terms from `BeyCatalog.creatorStore.searchTerms`
2. Insert mesh, copy `MeshId` / `TextureId`
3. Set in `BeyCatalog.modelAssets`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_MESH_ID",
    textureId = "rbxassetid://YOUR_TEXTURE_ID", -- optional
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Or add a `Models/<BeyId>` folder with imported Studio model (see NovaStriker).
