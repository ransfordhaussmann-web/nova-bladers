
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store Beys (optional mesh import)

Crimson Fang, Granite Fort, Solar Drift, Phantom Edge ship with procedural 3D models.
To use a Creator Store mesh instead, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ASSET_ID",
},
```

Search Roblox Studio Toolbox → Creator Store → "spinning top"
