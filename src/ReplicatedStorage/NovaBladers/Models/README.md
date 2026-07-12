# Bey Models — Studio Import

Place Creator Store or imported 3D models here for in-game use.

## Folder layout

After Studio import, each model lives under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | Studio model name | Creator Store search hint |
|-----|-------------------|---------------------------|
| Nova Striker | `NovaStriker` | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Iron Shell | `IronShell` | beyblade defense metal |
| Volt Dash | `VoltDash` | beyblade stamina yellow |
| Shadow Bite | `ShadowBite` | beyblade dark purple |
| Crimson Forge | `CrimsonForge` | beyblade attack red fire |
| Frost Prism | `FrostPrism` | beyblade ice crystal blue |

## Import steps

1. **Toolbox → Creator Store** — search the hint from `BeyCatalog.modelRef.creatorStoreSearch`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — `BeyModelBuilder` clones the model; procedural layers are skipped

If no Studio model exists, procedural 3D layers are built automatically.

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a full model. See `docs/BEY-MODELS.md`.
