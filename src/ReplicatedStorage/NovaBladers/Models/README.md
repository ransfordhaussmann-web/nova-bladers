# Creator Store Model Imports

Optional 3D models from Roblox Creator Store / Toolbox. Procedural fallbacks
in `BeyModelBuilder` are used when no Studio model is present.

## Import in Studio

1. Toolbox → Creator Store → search "spinning top" (no official IP names)
2. Import mesh into `ReplicatedStorage → NovaBladers → Models`
3. Name the model folder to match `studioModelName` in `BeyCatalog.lua`

| Model Name   | Bey          | Catalog ID   |
|--------------|--------------|--------------|
| NovaStriker  | Nova Striker | NovaStriker  |
| FrostPrism   | Frost Prism  | FrostPrism   |
| EmberCore    | Ember Core   | EmberCore    |

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from Toolbox.
