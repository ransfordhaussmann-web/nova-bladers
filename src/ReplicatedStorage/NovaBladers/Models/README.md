
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store models

Optional Studio models (Toolbox → Creator Store → spinning top):

| Model name   | Bey          | Notes                          |
|--------------|--------------|--------------------------------|
| NovaStriker  | Nova Striker | Sketchfab import (see above)   |
| CrimsonFang  | Crimson Fang | Falls back to procedural mesh  |
| FrostCrown   | Frost Crown  | Falls back to procedural mesh  |

Place imported models in this folder. `BeyModelBuilder` clones them when present;
otherwise procedural builders are used automatically.
