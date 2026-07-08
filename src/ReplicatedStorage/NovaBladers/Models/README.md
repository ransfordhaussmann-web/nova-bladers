# Bey Model Imports

Place optional Creator Store / imported 3D models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `FrostCrown` | Frost Crown | Toolbox → spinning top / ice theme |
| `CrimsonFang` | Crimson Fang | Toolbox → spinning top / attack theme |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (no folder import needed).

Without a model, procedural layers from `BeyModelBuilder.lua` are used automatically.
