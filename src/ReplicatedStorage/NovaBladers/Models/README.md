# Bey Models — Studio Import

Place Creator Store or imported 3D models here. `BeyModelBuilder` clones them at runtime when present; otherwise procedural layers are used.

## Folder names (match `modelRef.studioModelName` in BeyCatalog)

| Model folder | Bey |
|--------------|-----|
| `NovaStriker` | Nova Striker (Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonEdge` | Crimson Edge |
| `FrostHalo` | Frost Halo |

## How to import (Roblox Studio)

1. **Toolbox → Creator Store** — search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <Name>`
4. Set `PrimaryPart` on the collision hull; name it `Hull` if possible
5. Play — `BeyModelBuilder` auto-scales and welds to the physics hull

## Alternative: meshId in catalog

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of a Studio model folder.
