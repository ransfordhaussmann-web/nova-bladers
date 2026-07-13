
Import optional Creator Store / Sketchfab models here for in-game use.

| Folder | Bey |
|--------|-----|
| `NovaStriker` | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `CrimsonFang` | Crimson Fang — Toolbox → Creator Store → spinning top |
| `FrostCrown` | Frost Crown — same workflow |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`
Set `modelRef.studioModelName` in `BeyCatalog.lua` (already configured for new beys).
Or paste a mesh asset id into `modelAssets.meshId` to skip procedural layers.
