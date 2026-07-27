
Import optional Creator Store / Sketchfab models here for in-game use.

| Model name | Bey | Notes |
|------------|-----|-------|
| **NovaStriker** | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| **EmberCrown** | Ember Crown | Toolbox → Creator Store → "spinning top" / fire theme |
| **CrystalTide** | Crystal Tide | Toolbox → Creator Store → "spinning top" / ice theme |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural 3D layers are used automatically when no model is present.
Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a Model folder.
