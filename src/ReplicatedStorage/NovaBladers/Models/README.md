# Bey Model Imports

Optional Studio imports for higher-quality meshes. Procedural fallbacks work without these.

| Model folder | Bey | Creator Store search (Toolbox) |
|--------------|-----|--------------------------------|
| `NovaStriker` | Nova Striker | Sketchfab import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | `spinning top metal`, `bey defense shield` |
| `VoltDash` | Volt Dash | `spinning top yellow`, `flat top 3d` |
| `ShadowBite` | Shadow Bite | `spinning top dark`, `dragon top 3d` |
| `CrystalVortex` | Crystal Vortex | `crystal spinning top`, `ice beyblade` |
| `EmberRing` | Ember Ring | `fire spinning top`, `phoenix beyblade` |

## Import steps

1. Roblox Studio → Toolbox → Creator Store → search terms from table above
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` on the collision hull (name it `Hull` if possible)
5. Play — `BeyModelBuilder` clones the model when present, otherwise uses procedural layers

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart instead of a full model folder.
