# Creator Store Model Import

Place imported models under `ReplicatedStorage → NovaBladers → Models`.

## Studio import (recommended)

1. Open **Roblox Studio** → Toolbox → **Creator Store**
2. Search using the `creatorStoreSearch` hint from `BeyCatalog.lua`
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Name the model exactly as `studioModelName` in the catalog entry

| Bey | Studio folder name | Creator Store search hint |
|-----|-------------------|---------------------------|
| Nova Striker | `NovaStriker` | spinning top attack blue |
| Iron Shell | `IronShell` | spinning top defense green |
| Volt Dash | `VoltDash` | spinning top yellow lightning |
| Shadow Bite | `ShadowBite` | spinning top purple dark |
| Starfall Edge | `StarfallEdge` | spinning top red attack blade |
| Stone Halo | `StoneHalo` | spinning top stone gray defense |
| Thunder Coil | `ThunderCoil` | spinning top electric coil blue |
| Night Maw | `NightMaw` | spinning top dark fang red |

If no Studio model exists, procedural 3D layers are built automatically.

## MeshId shortcut

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

See `docs/BEY-MODELS.md` for full setup guide.
