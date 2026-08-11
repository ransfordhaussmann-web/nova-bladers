# Imported Bey Models

Place optional Creator Store or custom 3D models here as **Model** instances (one folder per bey id).

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `StarfallEdge` | Starfall Edge |
| `StoneHalo` | Stone Halo |
| `ThunderCoil` | Thunder Coil |
| `NightMaw` | Night Maw |

## Creator Store import

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Optional: copy **MeshId** into `BeyCatalog.lua` → `modelAssets.meshId`

Procedural layers are used when no Studio model or meshId is set.

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker only).
