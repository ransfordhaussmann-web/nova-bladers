
Import Creator Store or custom 3D models here for in-game use.

## Studio model names (match BeyCatalog.modelRef.studioModelName)

| Model folder | Bey |
|--------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| GraniteFort | Granite Fort |
| SolarDrift | Solar Drift |
| PhantomEdge | Phantom Edge |
| CrystalEdge | Crystal Edge |
| BlazeCrown | Blaze Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → [Name]`

If no model is present, `BeyModelBuilder` falls back to procedural 3D layers.
Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a Creator Store mesh.

See docs/BEY-MODELS.md
