# Bey Model Imports

Place imported FBX / Creator Store models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Optional Creator Store mesh |
| `VoltDash` | Volt Dash | Optional Creator Store mesh |
| `ShadowBite` | Shadow Bite | Optional Creator Store mesh |
| `CrystalTide` | Crystal Tide | Search Creator Store: "crystal top" |
| `EmberCore` | Ember Core | Search Creator Store: "fire top" |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Alternatively paste a `meshId` into `modelAssets` for a single MeshPart.
