# Nova Bladers — Studio Model Imports

Optional Creator Store / Sketchfab models for in-game use.
Procedural fallbacks exist for all 6 beys when no model is present.

## Model folder names (ReplicatedStorage → NovaBladers → Models)

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Blaze | `CrimsonBlaze` |
| Frost Crown | `FrostCrown` |

## Import steps

1. Insert model from Creator Store or import FBX/GLB in Studio
2. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
3. Set `PrimaryPart`, name collision part `Hull` if needed
4. Rojo sync → `BeyModelBuilder` clones and scales automatically (~3.5 stud diameter)

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` for details.
