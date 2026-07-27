# Creator Store / Studio Model Import

Import spinning-top models from the Roblox Creator Store or Blender into this folder.
Each bey has a `modelRef.studioModelName` in `BeyCatalog.lua` that maps to the folder name here.

## Expected folder names

| Bey | Folder name |
|-----|-------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Frost Prism | `FrostPrism` |
| Ember Core | `EmberCore` |

## How to import

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal`, etc.
3. Insert model into Workspace, scale to ~3–4 studs wide
4. Move to `ReplicatedStorage → NovaBladers → Models → <BeyName>`
5. Set `PrimaryPart` on the collision part (or name it `Hull`)
6. Play — `BeyModelBuilder` auto-clones and scales the model

If no Studio model is present, procedural 3D layers are used as fallback.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via the one-click tool.
