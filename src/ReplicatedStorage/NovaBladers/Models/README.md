
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store Beys (optional mesh import)

All 8 Beys support optional Creator Store models via `modelRef.studioModelName`.
Place imported models under `ReplicatedStorage/NovaBladers/Models/`:

| Bey | Studio folder name |
|-----|-------------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Fang | CrimsonFang |
| Granite Fort | GraniteFort |
| Solar Drift | SolarDrift |
| Phantom Edge | PhantomEdge |

Procedural 3D models are used as fallback when no Studio model is present.

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ASSET_ID",
},
```

Search Roblox Studio Toolbox → Creator Store → "spinning top"
