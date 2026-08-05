# Bey Studio Models

Import Creator Store or custom 3D models here for in-game use.

## Expected model names

| Studio folder name | Bey |
|--------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `GlacierSpin` | Glacier Spin |

## Import steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (pick a free model)
3. Insert into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models → <NameAbove>`
5. Set `PrimaryPart`, optional `Hull` on collision part, weld child parts

`BeyModelBuilder` clones these models when present; otherwise procedural layers are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import.
