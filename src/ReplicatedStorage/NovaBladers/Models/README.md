# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | Creator Store spin top, ~3.6 studs |
| `BlazeFang` | Blaze Fang | Attack-type, flat on arena |
| `FrostVeil` | Frost Veil | Defense-type, flat on arena |
| `CrimsonFang` | Crimson Fang | Optional Creator Store mesh |
| `GraniteFort` | Granite Fort | Optional Creator Store mesh |
| `SolarDrift` | Solar Drift | Optional Creator Store mesh |
| `PhantomEdge` | Phantom Edge | Optional Creator Store mesh |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` (Toolbox → Creator Store → spinning top).

If no model is present, `BeyModelBuilder` falls back to procedural 3D layers.
