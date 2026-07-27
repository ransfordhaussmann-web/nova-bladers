
Import Creator Store / Sketchfab models here for in-game use.

| Model folder name | Bey | Source |
|-------------------|-----|--------|
| **NovaStriker** | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| **EmberCrown** | Ember Crown | Toolbox → Creator Store (fire spinning top) |
| **CrystalTide** | Crystal Tide | Toolbox → Creator Store (crystal spinning top) |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallbacks render automatically when no Studio model is present.
Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart assets.
