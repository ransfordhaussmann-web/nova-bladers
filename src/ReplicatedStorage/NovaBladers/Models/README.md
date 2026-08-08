
Import Creator Store or custom 3D models here for in-game use.

## Studio folder layout

Place each model under `ReplicatedStorage/NovaBladers/Models/` with the matching name:

| Model Name | Bey |
|------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| GraniteFort | Granite Fort |
| SolarDrift | Solar Drift |
| PhantomEdge | Phantom Edge |
| CrystalEdge | Crystal Edge |
| BlazeCrown | Blaze Crown |

## Import options

1. **Studio Models folder** — set `modelRef.studioModelName` in `BeyCatalog.lua` (already configured for all 10 beys)
2. **Creator Store MeshId** — add `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`)
3. **Procedural fallback** — `BeyModelBuilder.lua` builds layered 3D models when no import is present

After Studio import: `ReplicatedStorage → NovaBladers → Models → [Name]`
