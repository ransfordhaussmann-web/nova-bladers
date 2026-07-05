
Import Creator Store / Sketchfab models here for in-game use.

## Supported model slots

| Studio folder | Bey | Notes |
|---------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrimsonFang` | Crimson Fang | Creator Store → attack spinning top |
| `FrostHalo` | Frost Halo | Creator Store → defense spinning top |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallbacks render automatically when no model is present.
Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart assets.
