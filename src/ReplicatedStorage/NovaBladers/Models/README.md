# Nova Bladers — Studio Model Imports

Place imported Creator Store / Sketchfab models here. `BeyModelBuilder` clones them automatically when present; otherwise procedural layers are used.

## Model folder names

| Bey | Studio folder name | Creator Store search terms |
|-----|-------------------|---------------------------|
| Nova Striker | `NovaStriker` | storm pegasus, attack top |
| Iron Shell | `IronShell` | defense beyblade, metal shield top |
| Volt Dash | `VoltDash` | yellow spinning top, lightning top |
| Shadow Bite | `ShadowBite` | purple spinning top, dark top |
| Crimson Blaze | `CrimsonBlaze` | red spinning top, fire top |
| Frost Crown | `FrostCrown` | ice spinning top, crystal top |

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store** (or import GLB via File → Import 3D)
2. Search using terms from the table above
3. Insert model into Workspace — check size (~3–4 studs wide) and flat orientation
4. Rename to the **Studio folder name** and move to:
   `ReplicatedStorage → NovaBladers → Models → <Name>`
5. Set `PrimaryPart` on the collision part; optional child named `Hull`
6. Play — the game scales and welds the mesh to the physics hull

## Alternative: MeshId only (no folder import)

In `BeyCatalog.lua`, add to any bey entry:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Procedural layers are skipped when `meshId` is set; spin ring is still added.

## Nova Striker (Sketchfab)

See `tools/nova-striker-import/README.md` for the automated GLB simplify pipeline.

- Sketchfab: https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660
- Credit: IcaroAndradeOliveira1

## Tuning scale / rotation

Edit `modelRef` in `BeyCatalog.lua`:

- `targetSize` — max dimension in studs (default ~3.5)
- `importRotation` — CFrame rotation if model imports upright
