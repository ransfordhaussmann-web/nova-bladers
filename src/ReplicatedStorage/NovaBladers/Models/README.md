
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store Beys (optional 3D import)

| Folder | Bey | Notes |
|--------|-----|-------|
| `CrimsonFang` | Crimson Fang | Attack store bey — red fang blades |
| `FrostHalo` | Frost Halo | Defense store bey — ice halo ring |

Procedural fallback models are built automatically if no Studio model is present.
Set `modelRef.studioModelName` in BeyCatalog to match the folder name.
