# Bey 3D Models (Creator Store / Studio Import)

Place imported models here as child **Model** instances. `BeyModelBuilder` clones them at runtime when present; otherwise procedural meshes are used.

| Studio model name | Bey | Import source |
|-------------------|-----|---------------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Creator Store / Toolbox → search "spinning top" |
| `FrostCrown` | Frost Crown | Creator Store / Toolbox → search "spinning top" |

## Quick import (Creator Store)

1. Roblox Studio → **Toolbox** → **Creator Store**
2. Search for a spinning-top mesh (no official Beyblade IP)
3. Insert into `ReplicatedStorage → NovaBladers → Models`
4. Rename the model to match `studioModelName` in `BeyCatalog.lua`
5. Optional: set `modelAssets.meshId` in the catalog for MeshPart fallback without a Studio model

## meshId fallback

If no Studio model exists, paste an asset id into `BeyCatalog.modelAssets.meshId`:

```lua
modelAssets = {
    meshId = "rbxassetid://123456789",
    size = Vector3.new(3.5, 1.0, 3.5),
},
```
