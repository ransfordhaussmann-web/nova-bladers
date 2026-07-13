# Creator Store Bey Models

Import 3D models into Studio under `ReplicatedStorage → NovaBladers → Models`.
Name each model exactly as `studioModelName` in `BeyCatalog.lua`.

When a matching model exists, the game clones it instead of the procedural fallback.

## All Beys

| studioModelName | In-game name | Suggested Creator Store search |
|-----------------|--------------|--------------------------------|
| `NovaStriker` | Nova Striker | spinning top attack, metal bey blade |
| `IronShell` | Iron Shell | spinning top defense, heavy metal top |
| `VoltDash` | Volt Dash | spinning top stamina, flat bey top |
| `ShadowBite` | Shadow Bite | spinning top balance, dark metal top |
| `CrimsonBlaze` | Crimson Blaze | spinning top fire, red attack top |
| `FrostCrown` | Frost Crown | spinning top ice, crystal defense top |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** (or import GLB via **File → Import 3D**)
2. Search using the terms above — pick a flat spinning-top mesh (~3–4 studs wide)
3. Rename the model to the `studioModelName` from the table
4. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Set **PrimaryPart** (or child part named `Hull`) for welding
6. **Play** — `BeyModelBuilder` auto-scales via `modelRef.targetSize`

## Optional: meshId shortcut

Instead of a Studio model folder, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for the automated GLB import script.
