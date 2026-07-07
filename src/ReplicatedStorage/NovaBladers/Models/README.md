
Import Creator Store / Sketchfab models here for in-game use.

## Supported model slots

| Model name     | Bey           | Notes                                      |
|----------------|---------------|--------------------------------------------|
| NovaStriker    | Nova Striker  | See docs/SKETCHFAB-NOVA-STRIKER.md         |
| FrostCrown     | Frost Crown   | Optional Creator Store mesh import         |
| CrimsonForge   | Crimson Forge | Optional Creator Store mesh import         |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallbacks render automatically when no imported model is present.
Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` for a MeshPart asset.
