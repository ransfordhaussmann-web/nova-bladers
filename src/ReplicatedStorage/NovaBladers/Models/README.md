# Nova Bladers — Studio Model Imports

Optional 3D meshes from Roblox Creator Store or custom imports.  
If no model exists in this folder, the game uses procedural layers from `BeyModelBuilder.lua`.

## Folder layout (after import in Studio)

```
ReplicatedStorage/NovaBladers/Models/
├── NovaStriker
├── IronShell
├── VoltDash
├── ShadowBite
├── CrimsonBlaze
└── FrostCrown
```

Each child must be a **Model** named exactly as in `BeyCatalog.modelRef.studioModelName`.

## Import steps (per Bey)

1. **Roblox Studio** → View → Toolbox → **Creator Store**
2. Search using `searchTerms` from `BeyCatalog.lua` (e.g. `spinning top`, `metal top`)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat on ground
4. Rename to the `studioModelName` (e.g. `CrimsonBlaze`)
5. Move to `ReplicatedStorage → NovaBladers → Models`
6. Set **PrimaryPart** (or name collision part `Hull`)
7. Play — `BeyModelBuilder` auto-clones and welds to physics hull

### Alternative: rbxassetid mesh

In `BeyCatalog.lua`, add instead of (or alongside) `modelRef`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Per-Bey reference

| Bey | Studio name | Target size | Search terms |
|-----|-------------|-------------|--------------|
| Nova Striker | NovaStriker | 3.5 | spinning top, attack top |
| Iron Shell | IronShell | 3.8 | spinning top, defense top |
| Volt Dash | VoltDash | 3.6 | spinning top, stamina ring |
| Shadow Bite | ShadowBite | 3.5 | spinning top, dark top |
| Crimson Blaze | CrimsonBlaze | 3.5 | spinning top, fire top |
| Frost Crown | FrostCrown | 3.9 | spinning top, ice top |

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker Sketchfab import.
