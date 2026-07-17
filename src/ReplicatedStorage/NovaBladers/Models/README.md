# Imported Bey Models

Place Creator Store or imported 3D models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Creator Store / custom import |
| `FrostSpiral` | Frost Spiral | Creator Store / custom import |

## Studio setup

1. Import or insert model under `ReplicatedStorage → NovaBladers → Models`
2. Name the model exactly as in the table (`studioModelName` in `BeyCatalog.lua`)
3. Set `PrimaryPart` or add a part named `Hull` for welding
4. `BeyModelBuilder` auto-scales to ~3.5 studs and lays the model flat

If no model is found, procedural layers are built at runtime.

## Optional meshId (no Studio import)

Add `modelAssets.meshId` in `BeyCatalog.lua` instead — see `docs/BEY-MODELS.md`.
