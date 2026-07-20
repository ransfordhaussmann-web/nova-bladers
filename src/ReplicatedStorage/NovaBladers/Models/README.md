# Bey Models (Studio Import)

Place imported Creator Store or custom 3D models here as **Model** instances named after each Bey id:

| Model Name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

`BeyModelBuilder` loads from this folder first (`modelRef.studioModelName`), then falls back to `modelAssets.meshId`, then procedural build.

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` for import steps.
