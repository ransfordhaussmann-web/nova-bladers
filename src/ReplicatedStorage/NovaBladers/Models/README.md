# Nova Bladers — 3D Model Import

Place imported Creator Store or custom models here. Each bey entry in `BeyCatalog.lua` has a `modelRef.studioModelName` that maps to a folder under this directory.

| Studio folder | Bey |
|---------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFlare` | Crimson Flare |
| `AquaSpiral` | Aqua Spiral |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, name collision part `Hull`, weld mesh parts
5. Play — `BeyModelBuilder` clones the model instead of procedural layers

## Alternative: meshId only

Set `modelAssets.meshId` in `BeyCatalog.lua` (no folder import needed). See `docs/BEY-MODELS.md`.

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.
