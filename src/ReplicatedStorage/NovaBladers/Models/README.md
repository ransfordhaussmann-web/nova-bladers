# Nova Bladers — Studio Model Imports

Place imported Creator Store / Sketchfab models here for in-game use.

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model Name | Bey | Notes |
|------------|-----|-------|
| **NovaStriker** | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| **IronShell** | Iron Shell | Creator Store / custom import |
| **VoltDash** | Volt Dash | Creator Store / custom import |
| **ShadowBite** | Shadow Bite | Creator Store / custom import |
| **CrimsonForge** | Crimson Forge | Creator Store / custom import |
| **FrostPrism** | Frost Prism | Creator Store / custom import |

## How it works

1. `BeyCatalog.modelRef.studioModelName` points to a child of this folder
2. `BeyModelBuilder` clones the model, scales to ~3.5 studs, welds to physics hull
3. If no model is found, procedural layers are built instead (always works offline)

## Import checklist

1. Scale: ~3–4 studs wide, flat on arena floor
2. Set **PrimaryPart** (or name collision part `Hull`)
3. Weld mesh parts together
4. Name exactly as in table above

## Creator Store search tips

Studio → Toolbox → Creator Store → search: `spinning top`, `metal top`, `arena top`

Avoid UGC waist accessories — look for game-ready mesh models.
