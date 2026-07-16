# Bey Studio Models (optional Creator Store imports)

Place imported Creator Store / custom 3D models here. Procedural fallbacks run when a model is missing.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Toolbox / Creator Store spinning top |
| `VoltDash` | Volt Dash | Toolbox / Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Toolbox / Creator Store spinning top |
| `CrystalVortex` | Crystal Vortex | Toolbox / Creator Store spinning top |
| `EmberRing` | Ember Ring | Toolbox / Creator Store spinning top |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` on the collision hull; name it `Hull` if possible
5. Play — `BeyModelBuilder` clones the model and welds it to the physics hull

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full model folder.
