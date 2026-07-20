# Bey 3D Models (Creator Store / Studio Import)

Import spinning-top models from Roblox Creator Store or Sketchfab into this folder.

## Priority (BeyModelBuilder)

1. **Models/** folder — clone `modelRef.studioModelName` from here
2. **modelAssets.meshId** in BeyCatalog — Toolbox mesh asset
3. Procedural fallback builder

## Expected model names

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | NovaStriker |
| Crimson Fang | CrimsonFang |
| Frost Crown | FrostCrown |

## Setup in Studio

1. Toolbox → Creator Store → search "spinning top" (no official IP names)
2. Insert model under `ReplicatedStorage → NovaBladers → Models`
3. Rename to match `studioModelName` in BeyCatalog
4. Optional: set `modelAssets.meshId` in BeyCatalog for MeshPart loading

See also: `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker GLB import.
