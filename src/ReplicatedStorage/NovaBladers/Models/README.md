# Nova Bladers — 3D Model Import

Optional Creator Store / Sketchfab models for in-game Bey visuals.

## Studio placement

After import, place models under:

`ReplicatedStorage → NovaBladers → Models`

## Supported model names

| Bey ID        | Studio model name | Notes                          |
|---------------|-------------------|--------------------------------|
| NovaStriker   | NovaStriker       | See docs/SKETCHFAB-NOVA-STRIKER.md |
| CrystalDrift  | CrystalDrift      | Stamina — crystal / ice theme  |
| CrimsonFang   | CrimsonFang       | Attack — magma / fang theme    |

## Creator Store mesh (alternative)

Set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_MESH_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Search Roblox Studio Toolbox → Creator Store → "spinning top".

Without imported models, procedural 3D builds are used automatically.
