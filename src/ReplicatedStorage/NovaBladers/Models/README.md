# Bey Model Imports

Place imported Studio models here for in-game use. Procedural fallbacks exist when a folder is missing.

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonEdge` | Crimson Edge | Creator Store or FBX import |
| `FrostGuard` | Frost Guard | Creator Store or FBX import |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`).
