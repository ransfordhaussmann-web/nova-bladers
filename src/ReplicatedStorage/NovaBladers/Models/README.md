# Bey Models — Studio Import

Import Creator Store or custom 3D models into `ReplicatedStorage/NovaBladers/Models/`.

## Expected model names

| Model Name | Bey | Type |
|------------|-----|------|
| `NovaStriker` | Nova Striker | Attack |
| `CrimsonFang` | Crimson Fang | Attack |
| `GraniteFort` | Granite Fort | Defense |
| `SolarDrift` | Solar Drift | Stamina |
| `PhantomEdge` | Phantom Edge | Balance |
| `CrystalEdge` | Crystal Edge | Attack |
| `BlazeCrown` | Blaze Crown | Balance |

Iron Shell, Volt Dash, and Shadow Bite use procedural models by default.

## How to import from Creator Store

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal`, `spin top`
3. Insert model into Workspace, scale to ~3.5 studs wide
4. Move to `ReplicatedStorage/NovaBladers/Models/[ModelName]`
5. Set `PrimaryPart`, name collision part `Hull`, weld all parts
6. Rojo sync → in-game the imported mesh replaces the procedural fallback

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
