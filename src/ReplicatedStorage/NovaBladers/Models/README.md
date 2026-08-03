
Import Creator Store / Sketchfab / custom 3D models here for in-game use.

## Folder names (studioModelName)

| Bey | Studio folder name |
|-----|-------------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Fang | `CrimsonFang` |
| Neon Pulse | `NeonPulse` |

## How to import

1. Open Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade` (fan models — no official IP)
3. Insert model into Workspace, resize to ~3–4 studs wide
4. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
5. Set `PrimaryPart` (or name collision part `Hull`)

**Nova Striker** can also use the Sketchfab import — see `docs/SKETCHFAB-NOVA-STRIKER.md`.

Without a Studio model, `BeyModelBuilder` falls back to procedural 3D layers automatically.

## Optional: meshId shortcut

Instead of a full model folder, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```
