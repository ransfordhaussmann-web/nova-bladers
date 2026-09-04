# Bey Studio Models

Import Creator Store or Sketchfab models here for in-game use.

## Model Names (match BeyCatalog.modelRef.studioModelName)

| Bey | Studio Model Name |
|-----|-------------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Fang | CrimsonFang |
| Frost Crown | FrostCrown |
| Solar Coil | SolarCoil |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for Creator Store meshes.
Procedural fallback models are built automatically when no import exists.
