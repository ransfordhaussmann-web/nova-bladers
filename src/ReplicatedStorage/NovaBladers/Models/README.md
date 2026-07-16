# Bey Model Import Slots

Place Creator Store or custom imported models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model Name | Bey | Creator Store Search Hint |
|------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | beyblade attack blue |
| `IronShell` | Iron Shell | beyblade defense shield metal |
| `VoltDash` | Volt Dash | spinning top yellow lightning |
| `ShadowBite` | Shadow Bite | dark spinning top purple |
| `CrimsonEdge` | Crimson Edge | red attack spinning top blade |
| `FrostHalo` | Frost Halo | ice crystal spinning top |

## Import in Studio

1. **Toolbox → Creator Store** — search using the hint above
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`), weld mesh parts
5. Play — `BeyModelBuilder` clones the model instead of procedural layers

## Alternative: meshId

In `BeyCatalog.lua`, set `modelAssets.meshId = "rbxassetid://..."` to use a single MeshPart without a full model folder.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of the reference Storm Pegasus mesh.
