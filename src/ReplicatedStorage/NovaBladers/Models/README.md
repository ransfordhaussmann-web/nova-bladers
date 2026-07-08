# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonForge` | Crimson Forge | Creator Store spin top → flat on ground |
| `FrostCrown` | Frost Crown | Creator Store spin top → flat on ground |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Without a model here, procedural builders in `BeyModelBuilder.lua` are used automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart from Toolbox.
