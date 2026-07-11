# Creator Store Bey Models

Import spinning-top models from the Roblox Creator Store (or your own FBX) into Studio.
`BeyModelBuilder` prefers a cloned model from this folder; otherwise it uses procedural layers.

## Model slots

| Studio model name | Bey | Type |
|-------------------|-----|------|
| `NovaStriker` | Nova Striker | Attack |
| `IronShell` | Iron Shell | Defense |
| `VoltDash` | Volt Dash | Stamina |
| `ShadowBite` | Shadow Bite | Balance |
| `BlazeLance` | Blaze Lance | Attack |
| `CoralTide` | Coral Tide | Stamina |

Path after import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Quick import (Creator Store)

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal`, or similar
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move under `ReplicatedStorage/NovaBladers/Models/` and rename to the slot name above
5. Set **PrimaryPart** (or name collision part `Hull`)
6. Play — `BeyModelBuilder` auto-scales and welds to the physics hull

## Alternative: MeshId only

In `BeyCatalog.lua`, set `modelAssets.meshId` instead of importing a full model:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.5, 1.2, 3.5),
},
```

Procedural layers are skipped when a mesh or imported model is present; the spin ring is still added.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of the reference mesh.
