# Creator Store / Studio Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.

After import, place each model under:
`ReplicatedStorage → NovaBladers → Models → [studioModelName]`

## Supported Beys (10)

| studioModelName | Bey | Fallback |
|-----------------|-----|----------|
| NovaStriker | Nova Striker | Procedural + Sketchfab ref |
| IronShell | Iron Shell | Procedural |
| VoltDash | Volt Dash | Procedural |
| ShadowBite | Shadow Bite | Procedural |
| CrimsonFang | Crimson Fang | Procedural |
| GraniteFort | Granite Fort | Procedural |
| SolarDrift | Solar Drift | Procedural |
| PhantomEdge | Phantom Edge | Procedural |
| CrystalEdge | Crystal Edge | Procedural |
| BlazeCrown | Blaze Crown | Procedural |

## Import priority

1. **Studio model** — `modelRef.studioModelName` matches folder name here
2. **MeshId** — set `modelAssets.meshId` in `BeyCatalog.lua` (rbxassetid)
3. **Procedural** — `BeyModelBuilder` builds a unique 3D model automatically

## Optional MeshId

In `BeyCatalog.lua`, add per Bey:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_MESH_ID",
    textureId = "rbxassetid://YOUR_TEXTURE_ID", -- optional
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Search Studio Toolbox → Creator Store → "spinning top" (use original IP names in-game).
