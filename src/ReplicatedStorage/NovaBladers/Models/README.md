# Creator Store Bey Models

Place imported Creator Store / Toolbox models here as **Model** instances.
`BeyModelBuilder` clones them when present; otherwise procedural fallbacks are used.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker (optional Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostRing` | Frost Ring |

Path after import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox mesh IDs.
