
Import Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| CrimsonFang | Crimson Fang | Toolbox → Creator Store → spinning top |
| FrostCrown | Frost Crown | Toolbox → Creator Store → spinning top |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallbacks in `BeyModelBuilder` are used when no Studio model is present.
Optional: set `modelAssets.meshId` in `BeyCatalog` for direct MeshPart import.
