# Bey Models — Studio Import

Place imported Creator Store / Sketchfab models here as **child Models** named after the bey id.

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker (Sketchfab: see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostRing` | Frost Ring |

**Path in Studio:** `ReplicatedStorage → NovaBladers → Models → <ModelName>`

When a model exists, `BeyModelBuilder` clones it instead of the procedural fallback.
Without a Studio model, procedural 3D layers are used automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox mesh IDs.
