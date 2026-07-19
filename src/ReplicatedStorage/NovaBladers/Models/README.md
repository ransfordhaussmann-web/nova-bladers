# Bey Studio Models

Import Creator Store or custom 3D models here for in-game use.

## Folder layout

Place one Model per bey under `ReplicatedStorage/NovaBladers/Models/`:

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<BeyId>`
4. Name collision part `Hull` (optional) and set `PrimaryPart`
5. Rojo sync — `BeyModelBuilder` clones from folder automatically

## Alternative: meshId in catalog

In `BeyCatalog.lua`, uncomment and set `modelAssets.meshId` for Crimson Fang or Frost Crown.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via `tools/nova-striker-import/`.
