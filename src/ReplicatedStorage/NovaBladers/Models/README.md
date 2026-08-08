
Import Creator Store / Sketchfab models here for in-game use.

## Studio import path

`ReplicatedStorage → NovaBladers → Models → [ModelName]`

| ModelName | Bey | Notes |
|-----------|-----|-------|
| NovaStriker | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostPrism | Frost Prism | Toolbox → Creator Store → spinning top |
| CrimsonFang | Crimson Fang | Toolbox → Creator Store → battle top |

## Alternative: meshId in catalog

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a Studio model.
Procedural builders in `BeyModelBuilder.lua` are used when no import is present.
