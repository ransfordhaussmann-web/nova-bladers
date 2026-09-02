
Import Creator Store / Sketchfab models here for in-game use.

## Supported Beys

| Model Name | Bey | Creator Store Search |
|------------|-----|---------------------|
| NovaStriker | Nova Striker | spinning top blue attack |
| CrimsonFang | Crimson Fang | spinning top red attack |
| GraniteFort | Granite Fort | spinning top stone defense |
| SolarDrift | Solar Drift | spinning top gold stamina |
| PhantomEdge | Phantom Edge | spinning top cyan balance |

## Import Steps

1. Roblox Studio → Toolbox → Creator Store → search term from table
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` on the collision hull, name it `Hull`
5. Rojo sync — procedural fallback used if model is missing

See docs/BEY-MODELS.md for full setup guide.
