
Import optional Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker (Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| CrimsonFang | Crimson Fang |
| GraniteFort | Granite Fort |
| SolarDrift | Solar Drift |
| PhantomEdge | Phantom Edge |
| CrystalEdge | Crystal Edge |
| BlazeCrown | Blaze Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Without imported models, procedural fallbacks from `BeyModelBuilder` are used automatically.
To use a Creator Store mesh instead, set `modelAssets.meshId` in `BeyCatalog.lua`.
