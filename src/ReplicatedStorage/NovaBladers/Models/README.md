
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store (optional)

Each Bey in `BeyCatalog.lua` can use `modelAssets.meshId` (rbxassetid) or
`modelAssets.creatorStoreSearch` as a Studio Toolbox hint.

| Bey | Toolbox-Suche |
|-----|---------------|
| Crimson Fang | spinning top red attack blade |
| Granite Fort | spinning top stone fortress |
| Solar Drift | spinning top solar gold ring |
| Phantom Edge | spinning top phantom blade |

Procedural 3D-Modelle werden automatisch gebaut, wenn kein Mesh importiert ist.
