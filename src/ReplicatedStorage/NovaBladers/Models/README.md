# Creator Store / Studio Models

Optional 3D meshes under `ReplicatedStorage/NovaBladers/Models/`.
If a model exists with the matching name, `BeyModelBuilder` clones it instead of the procedural mesh.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store / custom import |
| `VoltDash` | Volt Dash | Creator Store / custom import |
| `ShadowBite` | Shadow Bite | Creator Store / custom import |
| `FrostPrism` | Frost Prism | Creator Store / custom import |
| `BlazeRipper` | Blaze Ripper | Creator Store / custom import |

## Import in Studio

1. Toolbox → Creator Store → search `spinning top` (avoid official Beyblade IP)
2. Insert model, scale to ~3.5 studs wide, lay flat on arena
3. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
4. Set `PrimaryPart` or name collision part `Hull`
5. Play — procedural fallback is used until the model exists
