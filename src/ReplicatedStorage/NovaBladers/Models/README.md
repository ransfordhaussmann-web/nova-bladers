Import Sketchfab GLB or Creator Store models here for in-game use.

## Studio import

1. Roblox Studio → Toolbox → Creator Store → search "spinning top"
2. Insert model, rename to match `BeyCatalog` id (e.g. `CrimsonFang`)
3. Place under `ReplicatedStorage → NovaBladers → Models`
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for MeshPart fallback

## Procedural fallback

All 10 Beys have procedural 3D models in `BeyModelBuilder.lua` — no external assets required.

| Bey | Type | Studio model name |
|-----|------|-----------------|
| Nova Striker | Attack | NovaStriker |
| Iron Shell | Defense | IronShell |
| Volt Dash | Stamina | VoltDash |
| Shadow Bite | Balance | ShadowBite |
| Crimson Fang | Attack | CrimsonFang |
| Granite Fort | Defense | GraniteFort |
| Solar Drift | Stamina | SolarDrift |
| Phantom Edge | Balance | PhantomEdge |
| Crystal Edge | Attack | CrystalEdge |
| Blaze Crown | Balance | BlazeCrown |

See docs/SKETCHFAB-NOVA-STRIKER.md for Nova Striker Sketchfab import.
