# Bey Models (Creator Store / Studio Import)

Import spin-top meshes here for in-game use. Procedural fallbacks exist for all 6 beys until a mesh is added.

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store / Toolbox import |
| `VoltDash` | Volt Dash | Creator Store / Toolbox import |
| `ShadowBite` | Shadow Bite | Creator Store / Toolbox import |
| `CrimsonFang` | Crimson Fang | Creator Store / Toolbox import |
| `FrostCrown` | Frost Crown | Creator Store / Toolbox import |

## Studio setup

1. Import mesh into `ReplicatedStorage → NovaBladers → Models → {ModelName}`
2. Set `PrimaryPart` on the collision hull (or name it `Hull`)
3. `BeyModelBuilder` auto-scales via `modelRef.targetSize` (default ~3.5 studs)
4. Play → pick bey → imported mesh replaces procedural layers

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` for single-mesh Creator Store assets.
