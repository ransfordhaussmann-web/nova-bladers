# Bey Model Import Slots

Optional Creator Store / imported 3D models. Place a Model under this folder
with the matching name — `BeyModelBuilder` clones it instead of procedural build.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker (Sketchfab: see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonBlaze` | Crimson Blaze |
| `FrostCrown` | Frost Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <Name>`

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (Creator Store MeshId).
