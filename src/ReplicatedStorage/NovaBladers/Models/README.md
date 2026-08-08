# Bey Model Imports

Place imported Creator Store or Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones from `ReplicatedStorage/NovaBladers/Models/[studioModelName]`.

## Studio model names

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Fang | CrimsonFang |
| Granite Fort | GraniteFort |
| Solar Drift | SolarDrift |
| Phantom Edge | PhantomEdge |
| Crystal Edge | CrystalEdge |
| Blaze Crown | BlazeCrown |

## Import options

1. **Studio Models folder** — import GLB/mesh in Studio, place under `Models/[Name]`
2. **Creator Store meshId** — set `modelAssets.meshId` in `BeyCatalog.lua`

If no import is found, procedural fallback builders are used automatically.
