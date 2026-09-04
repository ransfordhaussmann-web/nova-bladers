# Bey Models (Studio import)

Optional Creator Store / imported 3D models. Procedural fallbacks exist for every bey.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |
| `SolarCoil` | Solar Coil |
| `BlazeQuill` | Blaze Quill |
| `TideAnchor` | Tide Anchor |

## Import steps

1. Roblox Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Rename to the model name above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Play → pick the bey to test

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart.
