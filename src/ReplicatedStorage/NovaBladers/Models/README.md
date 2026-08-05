# Creator Store / Studio Models

Import spinning-top models from Roblox Creator Store into Studio, then place them here as `Model` instances.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `GlacierSpin` | Glacier Spin |

Path after import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart loading.

Without a Studio model or mesh ID, procedural fallback visuals are used automatically.
