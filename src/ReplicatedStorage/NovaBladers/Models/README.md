# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. `BeyModelBuilder` clones them at runtime when present.

## Priority

1. **Models/ folder** — clone by `modelRef.studioModelName` (best quality)
2. **modelAssets.meshId** — single MeshPart from Creator Store asset ID
3. **Procedural** — layered parts built in code (fallback)

## Per-Bey Studio Names

| Bey | Folder Name | Creator Store search terms |
|-----|-------------|---------------------------|
| Nova Striker | `NovaStriker` | beyblade attack, pegasus, storm |
| Iron Shell | `IronShell` | beyblade defense, spinning top shield |
| Volt Dash | `VoltDash` | beyblade stamina, yellow spinning top |
| Shadow Bite | `ShadowBite` | beyblade balance, dark spinning top |
| Crimson Fang | `CrimsonFang` | beyblade attack, red spinning top, fang |
| Glacier Core | `GlacierCore` | beyblade ice, blue spinning top, crystal |

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
