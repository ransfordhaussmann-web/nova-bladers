# Bey Models (Studio Import)

Place imported Creator Store or custom 3D models here as **Model** instances:

| Model Name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

Path: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

`BeyModelBuilder` clones from this folder when present; otherwise it builds procedural layers or uses `modelAssets.meshId` from `BeyCatalog.lua`.

See `docs/BEY-MODELS.md` for Creator Store import steps.
