# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| Studio folder name | Bey |
|--------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCoil` | Frost Coil |

## Setup

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move under `ReplicatedStorage → NovaBladers → Models → <Name>`
4. Set `PrimaryPart`, name collision part `Hull`, weld mesh parts

If no Studio model exists, procedural layers are built automatically.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
