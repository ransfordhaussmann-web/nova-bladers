# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here as child **Models** of each bey id.

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `CrimsonFang` | Crimson Fang | Creator Store spinning top |
| `NeonPulse` | Neon Pulse | Creator Store spinning top |

## Import steps (Creator Store)

1. Roblox Studio → Toolbox → Creator Store
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
5. Optional: set `PrimaryPart` or name collision part `Hull`

Without a Studio model, `BeyModelBuilder` builds a procedural layered mesh automatically.

## Optional meshId shortcut

In `BeyCatalog.lua` per bey:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```
