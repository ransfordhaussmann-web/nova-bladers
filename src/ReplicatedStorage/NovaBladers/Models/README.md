# Bey Models (Studio Import)

Optional 3D meshes for in-game use. Procedural builders are used when no model is present.

| Folder name | Bey | Source |
|-------------|-----|--------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Creator Store / custom import |
| `FrostCoil` | Frost Coil | Creator Store / custom import |

## Creator Store mesh (quick)

1. Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model, copy **MeshId** from a mesh part
3. In `BeyCatalog.lua`, uncomment and fill `modelAssets.meshId` for the bey

## Studio folder import

1. Import FBX/GLB or insert Creator Store model
2. Move to `ReplicatedStorage → NovaBladers → Models → <BeyId>`
3. Set `modelRef.studioModelName` in `BeyCatalog.lua` (already set for new beys)

After import: Press Play and pick the bey to test.
