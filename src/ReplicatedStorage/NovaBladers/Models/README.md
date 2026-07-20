# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` is set in `BeyCatalog.lua`.

| Model Name   | Bey          |
|--------------|--------------|
| NovaStriker  | Nova Striker |
| IronShell    | Iron Shell   |
| VoltDash     | Volt Dash    |
| ShadowBite   | Shadow Bite  |
| CrimsonFang  | Crimson Fang |
| FrostCrown   | Frost Crown  |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search "spinning top"
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for MeshPart fallback

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
