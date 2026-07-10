# Bey Studio Models

Optional Creator Store / imported 3D models for in-game Beys.
Procedural fallback builds automatically when a model is missing.

## Import path (Rojo sync)

Place each model under `ReplicatedStorage/NovaBladers/Models/`:

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `FrostPrism` | Frost Prism |
| `BlazeRipper` | Blaze Ripper |

## Studio workflow

1. **Toolbox → Creator Store** → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — `BeyModelBuilder` clones, scales, welds, and adds spin ring

## Nova Striker (Sketchfab)

Import GLB via `tools/nova-striker-import/` or see `docs/SKETCHFAB-NOVA-STRIKER.md`.

## Optional meshId shortcut

Instead of a full Model folder, set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart.
