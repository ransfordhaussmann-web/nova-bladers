
Import 3D models here for in-game use. Folder name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Folder | Bey | Notes |
|--------|-----|-------|
| **NovaStriker** | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| **CrimsonFang** | Crimson Fang | Creator Store spin top (optional) |
| **FrostCore** | Frost Core | Creator Store spin top (optional) |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <FolderName>`

If a folder is missing, `BeyModelBuilder` uses procedural layers as fallback.
