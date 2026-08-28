
Import Sketchfab GLB or Creator Store models here for in-game use.

## Studio placement

ReplicatedStorage → NovaBladers → Models → `<ModelName>`

## Supported catalog models

| Model name   | Bey ID       | Creator Store search hint        |
|--------------|--------------|----------------------------------|
| NovaStriker  | NovaStriker  | (Sketchfab — see docs/)          |
| CrimsonFang  | CrimsonFang  | spinning top attack blade        |
| GraniteFort  | GraniteFort  | spinning top defense shield      |
| SolarDrift   | SolarDrift   | spinning top stamina ring        |
| PhantomEdge  | PhantomEdge  | spinning top balance dual        |

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from Toolbox.
Procedural fallbacks render automatically when no Studio model is present.
