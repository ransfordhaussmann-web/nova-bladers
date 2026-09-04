# Bey Studio Models

Import Creator Store or custom spinning-top models here for in-game use.

## Model names (must match `modelRef.studioModelName` in BeyCatalog)

| Bey | Studio model name |
|-----|-------------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Fang | CrimsonFang |
| Frost Crown | FrostCrown |
| Solar Coil | SolarCoil |

## Setup in Roblox Studio

1. Toolbox → Creator Store → search "spinning top" (or import custom mesh)
2. Place model under `ReplicatedStorage → NovaBladers → Models → <ModelName>`
3. Optional: set `modelAssets.meshId` in BeyCatalog for direct MeshPart fallback

Procedural fallback models are built automatically when no Studio model is present.
