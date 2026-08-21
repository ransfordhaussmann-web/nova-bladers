# Creator Store Bey Models

Import 3D models from Roblox Creator Store (or Sketchfab GLB) into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Supported Beys (6)

| Bey | studioModelName | Fallback |
|-----|-----------------|----------|
| Nova Striker | NovaStriker | Procedural + Sketchfab ref |
| Iron Shell | IronShell | Procedural |
| Volt Dash | VoltDash | Procedural |
| Shadow Bite | ShadowBite | Procedural |
| Blaze Drift | BlazeDrift | Procedural |
| Frost Crown | FrostCrown | Procedural |

## Import Steps (Studio)

1. Toolbox → Creator Store → search "spinning top" / "bey"
2. Insert model into workspace, rename to `studioModelName`
3. Move to `ReplicatedStorage/NovaBladers/Models/`
4. Set `PrimaryPart` or add a `Hull` part for physics weld

`BeyModelBuilder` auto-scales imported models to ~3.5 stud diameter and falls back to procedural geometry when no Studio model is present.

## Optional: Direct MeshPart IDs

Set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full Model:

```lua
modelAssets = {
    meshId = "rbxassetid://123456789",
    textureId = "rbxassetid://987654321", -- optional
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via the one-click tool.
