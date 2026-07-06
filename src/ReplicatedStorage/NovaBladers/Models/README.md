# Bey Models — Studio Import

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Folder name | Bey | Creator Store search terms |
|-------------|-----|--------------------------|
| `NovaStriker` | Nova Striker | spinning top blue, beyblade attack |
| `IronShell` | Iron Shell | spinning top defense, shield bey |
| `VoltDash` | Volt Dash | spinning top yellow, lightning bey |
| `ShadowBite` | Shadow Bite | spinning top dark, purple bey |
| `CrimsonOrbit` | Crimson Orbit | spinning top red, solar bey |
| `FrostAnchor` | Frost Anchor | spinning top ice, glacier bey |

## How to import

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using `searchTerms` from `BeyCatalog.lua` (e.g. "spinning top red")
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Set **PrimaryPart** (or name collision part `Hull`)

Procedural 3D layers are used automatically when no Studio model is present.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
