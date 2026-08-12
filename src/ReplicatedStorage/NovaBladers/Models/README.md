# Nova Bladers — Creator Store Model Imports

Place imported 3D models here under `ReplicatedStorage/NovaBladers/Models/`.
`BeyModelBuilder` clones them automatically when the folder + model name exist.

## Model slots (8 Beys)

| Studio model name | Bey | Creator Store search hint |
|-------------------|-----|----------------------------|
| `NovaStriker` | Nova Striker | spinning top attack blue |
| `IronShell` | Iron Shell | spinning top defense green |
| `VoltDash` | Volt Dash | spinning top yellow lightning |
| `ShadowBite` | Shadow Bite | spinning top dark purple |
| `StarfallEdge` | Starfall Edge | spinning top fire orange |
| `StoneHalo` | Stone Halo | spinning top stone heavy |
| `ThunderCoil` | Thunder Coil | spinning top electric coil |
| `NightMaw` | Night Maw | spinning top dark fang |

Search hints are also in `BeyCatalog.lua` → `modelRef.creatorStoreQuery`.

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search using the hint above (or `spinning top`, `spin arena`)
3. Insert model into Workspace — check size (~3–4 studs wide) and flat orientation
4. Rename to the **Studio model name** from the table
5. Move to `ReplicatedStorage/NovaBladers/Models/<StudioModelName>`
6. Optional: set `PrimaryPart` or name collision part `Hull`
7. Play — procedural fallback is skipped when the model is found

## Alternative: MeshId only

In `BeyCatalog.lua`, add per bey:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Fallback

If no Studio model and no `modelAssets.meshId`, a procedural 3D layered model is built at runtime.
