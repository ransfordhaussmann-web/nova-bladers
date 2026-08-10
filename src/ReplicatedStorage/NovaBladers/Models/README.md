# Nova Bladers — Bey Models

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker** for in-game use.
See `docs/SKETCHFAB-NOVA-STRIKER.md`

After Studio import: `ReplicatedStorage → NovaBladers → Models → NovaStriker`

## Creator Store Beys (Ember Coil, Aqua Prism)

1. Roblox Studio → **Toolbox** → **Creator Store**
2. Search: `spinning top`, `battle disk`, or `aqua disk`
3. Insert model into `ReplicatedStorage → NovaBladers → Models` (optional, named `EmberCoil` / `AquaPrism`)
4. **Or** copy the MeshPart **MeshId** into `BeyCatalog.lua` → `modelAssets.meshId`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_MESH_ID",
    size = Vector3.new(3.5, 1.1, 3.5),
},
```

Without a mesh, procedural 3D models are built automatically at runtime.
