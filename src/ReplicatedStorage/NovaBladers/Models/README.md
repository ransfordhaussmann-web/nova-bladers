# Creator Store Bey Models

Import optional 3D meshes from Roblox Creator Store or Sketchfab into Studio.
The game auto-clones from `ReplicatedStorage/NovaBladers/Models/` when present;
otherwise procedural models from `BeyModelBuilder.lua` are used.

## All 6 Beys

| Studio folder | Bey | Type |
|---------------|-----|------|
| `NovaStriker` | Nova Striker | Attack |
| `IronShell` | Iron Shell | Defense |
| `VoltDash` | Volt Dash | Stamina |
| `ShadowBite` | Shadow Bite | Balance |
| `ApexDrill` | Apex Drill | Attack |
| `NeonTide` | Neon Tide | Balance |

## Import steps (per Bey)

1. Open **Roblox Studio** → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal`, or the reference name from `BeyCatalog.modelRef`
3. Insert model into Workspace, scale to ~3.5 studs wide, flat on ground
4. Rename to the **Studio folder** name above (e.g. `ApexDrill`)
5. Move to: `ReplicatedStorage → NovaBladers → Models → <Name>`
6. Set **PrimaryPart** (or child part named `Hull`)
7. Play — game clones this instead of the procedural build

### Sketchfab (Nova Striker only)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for the GLB import workflow.

### Optional: rbxassetid mesh

In `BeyCatalog.lua`, add to any bey entry:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Files

| File | Purpose |
|------|---------|
| `BeyCatalog.lua` | Stats, colors, `modelRef`, optional `modelAssets` |
| `BeyModelBuilder.lua` | Procedural fallback + Studio model clone |
| `Models/<Name>/` | Imported Creator Store / Sketchfab meshes |
