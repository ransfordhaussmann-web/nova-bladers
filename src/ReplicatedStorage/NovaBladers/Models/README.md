# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. `BeyModelBuilder` clones them at runtime when present.

## Priority

1. **Models/ folder** — clone by `modelRef.studioModelName` (best quality)
2. **modelAssets.meshId** — single MeshPart from Creator Store asset ID
3. **Procedural** — layered parts built in code (fallback)

## Per-Bey Studio Names

| Bey | Folder Name | Creator Store search terms |
|-----|-------------|---------------------------|
| Nova Striker | `NovaStriker` | spinning top attack, storm top |
| Iron Shell | `IronShell` | spinning top shield, metal defense top |
| Volt Dash | `VoltDash` | spinning top flat, yellow stamina top |
| Shadow Bite | `ShadowBite` | dark spinning top, purple balance top |
| Crimson Fang | `CrimsonFang` | red spinning top, fang attack top |
| Frost Crown | `FrostCrown` | ice spinning top, blue crystal top |

## Import Steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using the terms above (or import your own GLB/FBX)
3. Scale to **~3.5 studs wide**, flat on arena floor
4. Rename model to the **Folder Name** from the table
5. Move to `ReplicatedStorage → NovaBladers → Models → <Name>`
6. Set **PrimaryPart** (or child part named `Hull`)
7. Play — game auto-clones instead of procedural build

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for automated GLB import.
