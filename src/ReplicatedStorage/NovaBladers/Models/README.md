# Bey Model Imports

Optional Studio-imported 3D models for Creator Store / custom meshes.

## Slots

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Import spinning-top mesh from Creator Store |
| `FrostSpiral` | Frost Spiral | Import ice/spiral top mesh from Creator Store |

## After Studio import

Place under: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `PrimaryPart`, name collision part `Hull`, weld parts. `BeyModelBuilder` auto-scales to ~3.5 studs.

## Creator Store meshId (alternative)

In `BeyCatalog.lua`, add `modelAssets.meshId = "rbxassetid://..."` to skip procedural layers.
