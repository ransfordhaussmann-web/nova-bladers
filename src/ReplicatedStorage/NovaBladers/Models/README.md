# Creator Store / Studio Bey Models

Import 3D models here for in-game use. Each bey in `BeyCatalog.lua` has a `modelRef.studioModelName` that maps to a child Model in this folder.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostHalo` | Frost Halo |

## How to import

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Rename to the **studio model name** from the table above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Set **PrimaryPart** (or name collision part `Hull`)
6. Play — `BeyModelBuilder` auto-clones the model instead of procedural layers

If no model is present, procedural 3D layers are used (no external assets required).

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker reference import)
