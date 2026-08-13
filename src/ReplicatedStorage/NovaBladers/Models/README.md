# Bey Models — Creator Store Import

Place imported 3D models here as **Model** instances. `BeyModelBuilder` clones them when `modelRef.studioModelName` matches.

| Model name | Bey | Import source |
|------------|-----|---------------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store → search "defense top" / "metal shell" |
| `VoltDash` | Volt Dash | Creator Store → search "stamina top" / "speed ring" |
| `ShadowBite` | Shadow Bite | Creator Store → search "balance top" / "dark blade" |
| `CrimsonBlaze` | Crimson Blaze | Creator Store → search "spinning top" / "battle top" |
| `FrostCrown` | Frost Crown | Creator Store → search "spinning top" / "crystal top" |

## Studio setup

1. **View → Toolbox → Creator Store**
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set **PrimaryPart** (or name collision part `Hull`)
5. Play — procedural fallback is used until the model exists here

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a full Model folder.
