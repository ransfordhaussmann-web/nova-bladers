
Import Creator Store / Sketchfab models here for in-game use.

## Studio model names

Place each model under `ReplicatedStorage → NovaBladers → Models`:

| Bey | Folder name |
|-----|-------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Blaze | CrimsonBlaze |
| Frost Orbit | FrostOrbit |

After import, `BeyModelBuilder` clones the Studio model when present; otherwise it falls back to procedural meshes.

## Creator Store meshId (optional)

In `BeyCatalog.lua`, set `modelAssets.meshId` to an rbxassetid from Toolbox → Creator Store.

See also `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker reference import.
