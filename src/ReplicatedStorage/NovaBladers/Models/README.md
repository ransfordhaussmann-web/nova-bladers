
Import optional Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker (Sketchfab — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| CrimsonFang | Crimson Fang |
| GraniteFort | Granite Fort |
| SolarDrift | Solar Drift |
| PhantomEdge | Phantom Edge |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`

Toolbox search hints are in `BeyCatalog.lua` → `modelAssets.creatorStoreSearch`.
Paste imported `rbxassetid` into `modelAssets.meshId` to use MeshPart fallback.
