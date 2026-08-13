# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. The game auto-clones them at runtime when `modelRef.studioModelName` matches the folder name in `BeyCatalog.lua`.

## Supported models

| Folder name | Bey | Notes |
|-------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Creator Store spinning top (flat, ~3.5 studs) |
| `AzureHalo` | Azure Halo | Creator Store spinning top (flat, ~3.6 studs) |

## Import steps

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top`
2. Insert model into Workspace, scale flat (~3.5 studs wide)
3. Rename to match table above (e.g. `CrimsonFang`)
4. Move to `ReplicatedStorage → NovaBladers → Models → CrimsonFang`
5. Set **PrimaryPart** (or child named `Hull`)
6. Play — procedural fallback is skipped when the Studio model exists

## Optional: meshId without full model

In `BeyCatalog.lua`, set `modelAssets.meshId` instead of importing a full model:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Procedural layers are used when neither Studio model nor `meshId` is set.
