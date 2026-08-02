# Bey 3D Models (Creator Store / Studio Import)

Optional Studio models for in-game Bey visuals. Without a model, procedural fallbacks are used.

| Studio Model Name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker (Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostCrown | Frost Crown |

## Setup

1. Roblox Studio → Toolbox → Creator Store → search "spinning top" / "bey"
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to match `studioModelName` in `BeyCatalog.lua`
4. Model auto-scales to `targetSize` (3.5 studs) via `BeyModelBuilder`

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart assets.
