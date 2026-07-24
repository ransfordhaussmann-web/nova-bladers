# Creator Store Bey Models

Import spinning-top models from Roblox Creator Store into Studio, then place them here.

## Priority (BeyModelBuilder)

1. **Models/** folder — clone `studioModelName` from this folder
2. **modelAssets.meshId** in BeyCatalog — Toolbox rbxassetid
3. Procedural fallback — built-in layered parts

## Model Slots

| studioModelName | Bey | Reference search |
|-----------------|-----|------------------|
| NovaStriker | Nova Striker | spinning top attack |
| IronShell | Iron Shell | defense bey |
| VoltDash | Volt Dash | stamina top |
| ShadowBite | Shadow Bite | balance top |
| CrimsonBlaze | Crimson Blaze | flame attack top |
| FrostCrown | Frost Crown | ice defense top |

## Studio Setup

After import: `ReplicatedStorage → NovaBladers → Models → <studioModelName>`

Optional in BeyCatalog `modelRef`:
- `targetSize` — scale to arena (default 3.5)
- `importRotation` — lay flat (default -90° X)

## Toolbox meshId (optional)

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ASSET_ID",
    textureId = "rbxassetid://...",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Search Creator Store: "spinning top" / "beyblade" (use as visual reference only — Nova Bladers is original IP).
