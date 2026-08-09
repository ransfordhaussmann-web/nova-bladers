# Creator Store / Studio Model Imports

Place imported spinning-top models under:

`ReplicatedStorage → NovaBladers → Models → [studioModelName]`

## Supported model names

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

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search "spinning top" (original IP only)
2. Insert model into `ReplicatedStorage/NovaBladers/Models/`
3. Rename to the `studioModelName` from the table above
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for MeshPart fallback

If no Studio model is present, `BeyModelBuilder` uses procedural 3D parts automatically.
