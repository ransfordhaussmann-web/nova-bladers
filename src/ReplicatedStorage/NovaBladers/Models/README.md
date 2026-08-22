# Creator Store / Imported Bey Models

Place imported Creator Store or Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones them automatically when `modelRef.studioModelName` matches.

## Expected model names

| Bey | Studio model name | Folder path |
|-----|-------------------|-------------|
| Nova Striker | `NovaStriker` | `ReplicatedStorage/NovaBladers/Models/NovaStriker` |
| Iron Shell | `IronShell` | `.../Models/IronShell` |
| Volt Dash | `VoltDash` | `.../Models/VoltDash` |
| Shadow Bite | `ShadowBite` | `.../Models/ShadowBite` |
| Crimson Vortex | `CrimsonVortex` | `.../Models/CrimsonVortex` |
| Glacier Mantle | `GlacierMantle` | `.../Models/GlacierMantle` |

## How to import

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade`
2. Insert model into Workspace, resize to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`
5. Rojo sync → play → pick bey → imported mesh replaces procedural layers

If no model is found, procedural 3D layers are used as fallback.
