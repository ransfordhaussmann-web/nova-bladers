
Import Creator Store or custom 3D models here for in-game use.

## Supported model folders

| Folder | Bey |
|--------|-----|
| `NovaStriker` | Nova Striker (Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `CrimsonFang` | Crimson Fang |
| `FrostHalo` | Frost Halo |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a folder.

Procedural fallback models are built automatically when no imported model is found.
