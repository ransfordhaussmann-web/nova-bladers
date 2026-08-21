# Creator Store Model Imports

Import Toolbox / Creator Store spin-top meshes into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | Folder name | Notes |
|-----|-------------|-------|
| Nova Striker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Iron Shell | `IronShell` | Heavy defense shell |
| Volt Dash | `VoltDash` | Flat stamina ring |
| Shadow Bite | `ShadowBite` | Dark balance type |
| Blaze Drift | `BlazeDrift` | Attack / fire theme |
| Frost Crown | `FrostCrown` | Defense / ice theme |

## Steps

1. Studio → Toolbox → Creator Store → search `spinning top` (avoid official Beyblade IP names in-game)
2. Insert model, scale to ~3.5 studs wide, lay flat on arena
3. Rename to the folder name above
4. Move to `ReplicatedStorage/NovaBladers/Models/`
5. Set `PrimaryPart` or child part named `Hull`

If no Studio model exists, `BeyModelBuilder` falls back to procedural layers.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart IDs.
