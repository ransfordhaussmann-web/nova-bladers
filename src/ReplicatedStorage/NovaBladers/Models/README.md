# Bey 3D Models (Creator Store / Studio Import)

Import optional spinning-top meshes from Roblox Creator Store or Sketchfab.

## Priority (BeyModelBuilder)

1. **Models/** folder — clone `modelRef.studioModelName` from here
2. **modelAssets.meshId** — single MeshPart from Creator Store
3. **Procedural** — built-in layered 3D fallback

## Studio Import Slots

| Model Name   | Bey          | Notes                          |
|--------------|--------------|--------------------------------|
| NovaStriker  | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| CrimsonFang  | Crimson Fang | Attack blades, red accent      |
| FrostHalo    | Frost Halo   | Ice ring, glass halo           |

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store meshId

In `BeyCatalog.lua`, uncomment and set `modelAssets.meshId`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ASSET_ID",
    size = Vector3.new(3.5, 1.1, 3.5),
},
```

Search Toolbox → Creator Store → "spinning top" / "beyblade" (use as visual reference only).
