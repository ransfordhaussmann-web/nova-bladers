# Nova Bladers — Studio Model Imports

Place imported Creator Store or custom 3D models here. `BeyModelBuilder` clones by `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Optional Creator Store import |
| `VoltDash` | Volt Dash | Optional Creator Store import |
| `ShadowBite` | Shadow Bite | Optional Creator Store import |
| `CrimsonBlaze` | Crimson Blaze | Optional Creator Store import |
| `FrostOrbit` | Frost Orbit | Optional Creator Store import |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`), weld mesh parts
5. Play — procedural layers are skipped when a matching model exists

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a folder model.
