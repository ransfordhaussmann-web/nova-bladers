# Nova Bladers — Imported 3D Models

Place Studio-imported models here. Procedural layers are used until a matching folder exists.

| Folder | Bey | Source |
|--------|-----|--------|
| `NovaStriker` | Nova Striker | Sketchfab GLB (see `docs/SKETCHFAB-NOVA-STRIKER.md`) |
| `CrimsonFang` | Crimson Fang | Creator Store / custom FBX |
| `FrostCrown` | Frost Crown | Creator Store / custom FBX |

## Quick import (Creator Store)

1. Studio → **Toolbox → Creator Store** → search hints in `BeyCatalog.modelRef.creatorStoreSearch`
2. Insert model, scale to ~3.5 studs wide, lay flat on ground
3. Set **PrimaryPart** (or name collision part `Hull`)
4. Move model into this folder with the exact name from the table
5. Optional: copy **MeshId** into `BeyCatalog.modelAssets.meshId` for single-mesh fallback

After import: **Play** → pick the bey → imported mesh replaces procedural visuals.
