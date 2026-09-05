
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store meshes

Optional MeshPart assets for any Bey — set `modelAssets.meshId` in `BeyCatalog.lua`:

1. Roblox Studio → Toolbox → Creator Store → search "spinning top"
2. Insert mesh, copy MeshId (rbxassetid://…)
3. Paste into the Bey's `modelAssets.meshId` field

Blaze Orbit and Frost Crown have `modelAssets` slots ready. Procedural models are used as fallback.
