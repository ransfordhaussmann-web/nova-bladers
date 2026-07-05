
Import Creator Store or Sketchfab models here for in-game use.

## Supported model folders

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `BlazeSurge` | Blaze Surge | Creator Store spinning-top model |
| `CrystalGuard` | Crystal Guard | Creator Store crystal/defense model |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallback models are built automatically when no imported model is found.
Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart assets.
