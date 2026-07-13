# Bey Studio Models

Place imported Creator Store or Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones them when `BeyCatalog.modelRef.studioModelName` matches.

| Model name | Bey | Import notes |
|------------|-----|--------------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Toolbox → flat spin top ~3.6 studs |
| `VoltDash` | Volt Dash | Flat stamina-style ring preferred |
| `ShadowBite` | Shadow Bite | Asymmetric / fang shapes work well |
| `CrimsonBlaze` | Crimson Blaze | Attack blades, red/orange palette |
| `FrostCrown` | Frost Crown | Crown spikes, ice/defense look |

## Studio path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Alternative: meshId only

In `BeyCatalog.lua`, set `modelAssets.meshId = "rbxassetid://…"` on any bey.
Procedural layers are skipped when a valid meshId is set.

## After import

1. Set model `PrimaryPart` (or name collision part `Hull`)
2. Scale in Studio if needed, or adjust `modelRef.targetSize` in catalog
3. Play → pick bey → verify spin ring + physics hull
