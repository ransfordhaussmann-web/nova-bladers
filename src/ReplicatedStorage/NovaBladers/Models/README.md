# Bey Model Imports (Creator Store / Sketchfab)

Place imported 3D models here as **Model** instances. `BeyModelBuilder` clones them when `modelRef.studioModelName` matches the folder name.

| Folder name | Bey | Source |
|-------------|-----|--------|
| `NovaStriker` | Nova Striker | Sketchfab GLB (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell | Creator Store → Toolbox → insert → move here |
| `VoltDash` | Volt Dash | Creator Store spinning top mesh |
| `ShadowBite` | Shadow Bite | Creator Store spinning top mesh |
| `BlazeDrift` | Blaze Drift | Creator Store spinning top mesh |
| `FrostCrown` | Frost Crown | Creator Store spinning top mesh |

## Studio path

`ReplicatedStorage` → `NovaBladers` → `Models` → `{BeyId}`

## Creator Store workflow

1. Toolbox → Creator Store → search `spinning top` or `bey blade metal`
2. Insert model, scale to ~3.5 studs wide, lay flat
3. Rename to match `studioModelName` in `BeyCatalog.lua`
4. Move under `Models/` (or parent in Rojo sync tree)
5. Optional: copy MeshId into `modelAssets.meshId` in `BeyCatalog.lua`

Procedural layered models are used automatically when no imported model is found.
