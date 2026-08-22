# Bey Models — Studio Import Slots

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` is set in `BeyCatalog.lua`.

## Model slots (6 Beys)

| studioModelName | Bey | Fallback |
|-----------------|-----|----------|
| `NovaStriker` | Nova Striker | Procedural attack blades |
| `IronShell` | Iron Shell | Procedural shell segments |
| `VoltDash` | Volt Dash | Procedural stamina ring |
| `ShadowBite` | Shadow Bite | Procedural dark fangs |
| `CrimsonVortex` | Crimson Vortex | Procedural spiral fins |
| `GlacierMantle` | Glacier Mantle | Procedural ice plates |

## How to add a Creator Store model

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`
5. Play — `BeyModelBuilder` auto-scales and welds to physics hull

## Alternative: meshId in catalog

Add `modelAssets = { meshId = "rbxassetid://..." }` to a bey entry in `BeyCatalog.lua`.

## Nova Striker Sketchfab import

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import workflow.
