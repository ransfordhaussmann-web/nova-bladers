
Import Creator Store / Sketchfab models here for in-game use.

| Model name   | Bey          | Studio path                                      |
|--------------|--------------|--------------------------------------------------|
| NovaStriker  | Nova Striker | ReplicatedStorage → NovaBladers → Models         |
| CrimsonFang  | Crimson Fang | Toolbox → Creator Store → spinning top import    |
| FrostCrown   | Frost Crown  | Toolbox → Creator Store → spinning top import    |

After Studio import: place Model under `ReplicatedStorage/NovaBladers/Models/`.
Procedural fallback builds automatically when no Studio model is present.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` to override with a rbxassetid.
