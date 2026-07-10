# Creator Store / Studio Models

Import spinning-top models from Roblox Creator Store into Studio, then place them here.

## Folder names (must match `studioModelName` in `BeyCatalog.lua`)

| Bey | Studio folder |
|-----|---------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Frost Prism | `FrostPrism` |
| Blaze Ripper | `BlazeRipper` |

## Import steps

1. Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models → <FolderName>`
5. Optional: set `PrimaryPart` or name collision part `Hull`

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D layers.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
