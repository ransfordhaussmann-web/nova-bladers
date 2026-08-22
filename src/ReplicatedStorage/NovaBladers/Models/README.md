# Bey Models — Studio Import Folder

Place Creator Store or imported 3D models here as **Model** instances.
Rojo syncs this folder to `ReplicatedStorage/NovaBladers/Models`.

## Expected model names

| Studio model name | Bey | Creator Store search hint |
|-------------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | beyblade attack blue pegasus |
| `IronShell` | Iron Shell | beyblade defense green shell |
| `VoltDash` | Volt Dash | beyblade yellow stamina spinning |
| `ShadowBite` | Shadow Bite | beyblade purple dark balance |
| `CrimsonForge` | Crimson Forge | beyblade red fire attack forge |
| `FrostCrown` | Frost Crown | beyblade ice blue frost defense |

## How to add a Creator Store model

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using the `creatorStoreQuery` from `BeyCatalog.lua`
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Set `PrimaryPart` or name collision part `Hull`
6. Play — `BeyModelBuilder` clones this instead of procedural layers

Procedural 3D layers are the fallback when no Studio model is present.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import workflow.
