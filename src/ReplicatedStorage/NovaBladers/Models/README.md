# Creator Store Bey Models

Import optional 3D models from Roblox Studio Toolbox → Creator Store.

## Studio folder layout

After import, place models under:

```
ReplicatedStorage → NovaBladers → Models → <studioModelName>
```

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Starfall Edge | StarfallEdge |
| Stone Halo | StoneHalo |
| Thunder Coil | ThunderCoil |
| Night Maw | NightMaw |

## Option A — Studio model folder

1. Insert a Creator Store spinning-top model into Workspace
2. Scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Name collision part `Hull`, set `PrimaryPart`

`BeyModelBuilder` auto-clones from this folder when present.

## Option B — MeshId in catalog

In `BeyCatalog.lua`, uncomment and set `modelAssets.meshId`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Procedural layers are skipped when `meshId` is set.

## Fallback

Without imported assets, each bey uses its procedural 3D builder in `BeyModelBuilder.lua`.
