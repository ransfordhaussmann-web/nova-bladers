# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeComet` | Blaze Comet |
| `FrostCrown` | Frost Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <Name>`

The game auto-clones these models instead of procedural builds when present.
Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart.
