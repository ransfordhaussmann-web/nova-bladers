# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. `BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonVortex` | Crimson Vortex | Creator Store spinning top, ~3.6 studs wide |
| `FrostCrown` | Frost Crown | Creator Store / custom ice crown, ~3.7 studs wide |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` or import FBX/GLB
2. Move model to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
3. Set `PrimaryPart` on the collision hull (or name a part `Hull`)
4. Play — `BeyModelBuilder` scales via `modelRef.targetSize` in `BeyCatalog.lua`

Optional: set `modelAssets.meshId` in the catalog entry to use a single MeshPart without a Studio folder model.
