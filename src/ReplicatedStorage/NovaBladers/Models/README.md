
Import optional 3D models here for in-game use.

## Studio placement

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model name   | Bey          | Notes |
|--------------|--------------|-------|
| NovaStriker  | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostCrown   | Frost Crown  | Creator Store / FBX import (~3.5 stud diameter) |
| CrimsonFang  | Crimson Fang | Creator Store / FBX import (~3.5 stud diameter) |

## Creator Store mesh (no folder import)

In `BeyCatalog.lua`, set `modelAssets.meshId` on the bey entry:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Without import or meshId, procedural builders in `BeyModelBuilder.lua` are used.
