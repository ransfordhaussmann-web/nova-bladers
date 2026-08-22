# Creator Store / Imported Models

Place imported 3D models here as **Model** instances. The game clones them at runtime when present; otherwise procedural layers are used.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeComet` | Blaze Comet |
| `FrostCrown` | Frost Crown |

**Path in Studio:** `ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## How to add a Creator Store model

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move under `ReplicatedStorage/NovaBladers/Models/` and rename to the `studioModelName` above
5. Set `PrimaryPart` (or name collision part `Hull`)

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker GLB import).
