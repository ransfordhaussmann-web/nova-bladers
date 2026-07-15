# Bey Model Imports

Place Studio-imported models here for in-game use.

| Folder name | Bey | Notes |
|-------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrimsonFang` | Crimson Fang | Creator Store or custom FBX import |
| `GlacierShield` | Glacier Shield | Creator Store or custom FBX import |

After import: set `PrimaryPart`, name collision part `Hull`, weld mesh parts.

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (no folder needed).

Procedural fallback models are built automatically when no import is present.
