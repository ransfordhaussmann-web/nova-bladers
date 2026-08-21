# Bey Model Imports

Optional Creator Store / custom 3D models for in-game Beys.

Place imported **Model** instances here (Rojo sync from Studio):

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeDrift` | Blaze Drift |
| `FrostCrown` | Frost Crown |

## Studio workflow

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <FolderName>`
4. Set `PrimaryPart` (or name collision part `Hull`), weld mesh parts
5. Play — `BeyModelBuilder` clones the Studio model when present; otherwise procedural fallback

## Sketchfab (Nova Striker)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of Nova Striker.

## Direct mesh ID (no Studio folder)

In `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```
