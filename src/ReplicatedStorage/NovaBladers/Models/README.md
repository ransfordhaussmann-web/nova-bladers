
Import optional Creator Store / Sketchfab models here for in-game use.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrystalDrift` | Crystal Drift | Toolbox → spinning top / crystal → save as Model |
| `CrimsonFang` | Crimson Fang | Toolbox → attack top / flame → save as Model |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` (procedural fallback stays active until meshId is set).
