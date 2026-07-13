# Creator Store Model Imports

Import free Toolbox / Creator Store spinning-top models into Studio, then place them here so `BeyModelBuilder` can clone them at runtime.

**Path:** `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Model names (must match exactly)

| Model Name     | Bey           | Toolbox search terms                          |
|----------------|---------------|-----------------------------------------------|
| `NovaStriker`  | Nova Striker  | beyblade attack, spinning top blue, pegasus   |
| `IronShell`    | Iron Shell    | beyblade defense, spinning top green          |
| `VoltDash`     | Volt Dash     | beyblade stamina, spinning top yellow         |
| `ShadowBite`   | Shadow Bite   | beyblade balance, spinning top purple         |
| `CrimsonBlaze` | Crimson Blaze | beyblade attack, spinning top red, fire bey   |
| `FrostCrown`   | Frost Crown   | beyblade ice, spinning top blue, crystal bey  |

## Import steps

1. Open **Roblox Studio** → **View → Toolbox → Creator Store**
2. Search using the terms above (or `beyblade`, `spinning top`, `metal fusion`)
3. Insert a model into Workspace — check size (~3–4 studs wide) and flat orientation
4. Rename the model to the **Model Name** from the table
5. Move it to `ReplicatedStorage/NovaBladers/Models/`
6. Optional: set `PrimaryPart` or name the collision part `Hull`
7. Play — if no Studio model is found, the procedural fallback is used automatically

## Alternative: meshId in catalog

Instead of a Studio folder model, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via the one-click tool.
