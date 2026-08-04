# Bey Models (Creator Store / Studio Import)

Procedural models are built at runtime when no imported mesh is found.
To use a Creator Store or imported model:

## Option A — Studio model (recommended for GLB imports)

1. Import mesh in Roblox Studio (Toolbox → Creator Store → "spinning top")
2. Place under `ReplicatedStorage → NovaBladers → Models`
3. Name the model to match `modelRef.studioModelName` in `BeyCatalog.lua`

| Bey ID       | Studio model name |
|--------------|-------------------|
| NovaStriker  | NovaStriker       |
| CrimsonFang  | CrimsonFang       |
| AquaPrism    | AquaPrism         |

See `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker GLB import steps.

## Option B — rbxassetid mesh

In `BeyCatalog.lua`, set `modelAssets.meshId` to your Creator Store asset id:

```lua
modelAssets = {
    meshId = "1234567890",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade" (use only as search terms; game uses original Nova Bladers names).
