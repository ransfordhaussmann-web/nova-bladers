# Bey Models (Studio import)

Place imported 3D models here as **Model** instances. `BeyModelBuilder` clones them when `modelRef.studioModelName` is set in `BeyCatalog.lua`.

| Model name | Bey | Notes |
|------------|-----|-------|
| **NovaStriker** | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| **CrimsonFang** | Crimson Fang | Creator Store / Toolbox spinning top |
| **FrostCrown** | Frost Crown | Creator Store / Toolbox spinning top |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a folder model.
