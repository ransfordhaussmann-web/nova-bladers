
Import Creator Store or custom 3D models here for in-game use.

## Supported model names

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonFang` | Crimson Fang |
| `GraniteFort` | Granite Fort |
| `SolarDrift` | Solar Drift |
| `PhantomEdge` | Phantom Edge |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store import (optional)

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using `creatorStoreSearch` from `BeyCatalog.lua` (e.g. `spinning top metal red attack`)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Set `PrimaryPart` and name collision part `Hull` if needed

Procedural layers are used when no Studio model is found. Optional `modelAssets.meshId` in catalog skips procedural build.

See `docs/BEY-MODELS.md` for full setup.
