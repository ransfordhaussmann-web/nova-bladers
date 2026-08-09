# Bey Model Imports

Place Creator Store or custom 3D models here for in-game use.

## Supported model names

| Studio folder name | Bey |
|--------------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonFang` | Crimson Fang |
| `GraniteFort` | Granite Fort |
| `SolarDrift` | Solar Drift |
| `PhantomEdge` | Phantom Edge |
| `CrystalEdge` | Crystal Edge |
| `BlazeCrown` | Blaze Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → [Name]`

## Alternative: meshId in catalog

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a model folder.
Procedural fallback visuals are used when no import is present.

See `docs/BEY-MODELS.md` for full setup instructions.
