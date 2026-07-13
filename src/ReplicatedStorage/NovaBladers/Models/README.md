# Bey Models — Studio Import

Procedural 3D models are built at runtime. For higher-quality meshes, import Creator Store or custom models into this folder.

## Import workflow (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search using the `creatorStoreQuery` from `BeyCatalog.lua`
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Rename to the `studioModelName` below

When a matching model exists, `BeyModelBuilder` clones it instead of procedural layers.

## Bey → Studio model name

| Bey | Studio folder name | Creator Store search |
|-----|-------------------|----------------------|
| Nova Striker | `NovaStriker` | attack spinning top blue metal |
| Iron Shell | `IronShell` | defense spinning top green metal shell |
| Volt Dash | `VoltDash` | stamina spinning top yellow lightning |
| Shadow Bite | `ShadowBite` | balance spinning top purple dark |
| Blaze Orbit | `BlazeOrbit` | fire spinning top orange flame |
| Crystal Guard | `CrystalGuard` | crystal spinning top ice glass |

## Optional: meshId shortcut

Set `modelAssets.meshId` in `BeyCatalog.lua` to skip procedural layers entirely:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.
