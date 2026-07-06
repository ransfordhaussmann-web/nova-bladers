# Bey Studio Models

Optional Creator Store / imported models for in-game Bey visuals.

Place each model under `ReplicatedStorage → NovaBladers → Models` with the exact name from `BeyCatalog.modelRef.studioModelName`.

| Model name | Bey | Notes |
|------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| IronShell | Iron Shell | Procedural fallback if missing |
| VoltDash | Volt Dash | Procedural fallback if missing |
| ShadowBite | Shadow Bite | Procedural fallback if missing |
| CrimsonBlaze | Crimson Blaze | Creator Store import or procedural fallback |
| FrostOrbit | Frost Orbit | Creator Store import or procedural fallback |

## Creator Store workflow

1. Roblox Studio → Toolbox → Creator Store → search spinning top / arena fighter
2. Insert model into `Models/` folder and rename to `studioModelName`
3. Or set `modelAssets.meshId` in `BeyCatalog.lua` with the asset id

If no model is present, `BeyModelBuilder` builds a procedural 3D Bey automatically.
