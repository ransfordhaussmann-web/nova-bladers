# Bey Models (Creator Store / Studio Import)

Optional 3D models under `ReplicatedStorage/NovaBladers/Models/`.
If a model exists, `BeyModelBuilder` clones it instead of the procedural fallback.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeForge` | Blaze Forge |
| `FrostPrism` | Frost Prism |

## Import in Studio

1. Toolbox → Creator Store → search `spinning top` / `bey blade` (no official IP names in game)
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` or name collision part `Hull`
5. Play — `BeyModelBuilder` auto-scales and welds to physics hull

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker reference).
