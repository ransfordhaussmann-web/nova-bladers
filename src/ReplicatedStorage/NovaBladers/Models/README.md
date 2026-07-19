# Bey Models (Studio Import)

Import Creator Store or custom 3D models here as **Model** instances named after `studioModelName` in `BeyCatalog.lua`.

| Studio folder name | Bey |
|--------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

**Path after import:** `ReplicatedStorage → NovaBladers → Models → <Name>`

If no model is present, `BeyModelBuilder` falls back to procedural layers. Optional `modelAssets.meshId` in the catalog overrides procedural when set.

See `docs/BEY-MODELS.md` for Toolbox / Creator Store workflow.
