# Bey model imports (optional)

Procedural 3D layers are built at runtime when no imported model is found.

## Studio import (recommended quality)

Import a GLB/FBX or insert a Creator Store model, then place it here:

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonDrift` | Crimson Drift |
| `FrostCrown` | Frost Crown |

Path: `ReplicatedStorage → NovaBladers → Models → <FolderName>`

See `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker GLB workflow.

## Creator Store mesh ID (quick)

In `BeyCatalog.lua`, uncomment and set `modelAssets.meshId` for any bey:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Search Studio Toolbox → Creator Store → `spinning top` / `bey blade metal`.
