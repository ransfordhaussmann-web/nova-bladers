# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Model Name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

Path: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

`BeyModelBuilder` loads these automatically via `modelRef.studioModelName` in `BeyCatalog.lua`.
If no model is found, procedural layers are used instead.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart from Toolbox.

See `docs/BEY-MODELS.md` for import steps.
