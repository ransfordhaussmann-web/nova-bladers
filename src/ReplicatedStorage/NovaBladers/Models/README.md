# Bey Studio Models

Optional Creator Store / Studio imports for in-game Bey visuals.

`BeyModelBuilder` priority: `Models/` folder → `modelAssets.meshId` → procedural fallback.

## Import names

| Bey | Studio model name | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Crimson Fang | `CrimsonFang` | Attack Bey — flame blades |
| Glacier Spin | `GlacierSpin` | Defense Bey — ice crystal ring |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for Creator Store mesh overrides.
