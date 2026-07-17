
Optional imported 3D models for in-game Beys.
Drop a Studio model here to replace the procedural mesh at runtime.

| Folder name   | Bey           | Import notes                          |
|---------------|---------------|---------------------------------------|
| NovaStriker   | Nova Striker  | See docs/SKETCHFAB-NOVA-STRIKER.md    |
| IronShell     | Iron Shell    | ~3.6 studs wide, flat on arena floor  |
| VoltDash      | Volt Dash     | Wide flat ring style works best       |
| ShadowBite    | Shadow Bite   | Asymmetric dark top                   |
| CrimsonEdge   | Crimson Edge  | Sharp attack blades, red/orange       |
| FrostHalo     | Frost Halo    | Heavy ice/defense look                |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<FolderName>`

Set **PrimaryPart** (or child named `Hull`). The game auto-scales and welds on spawn.

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` for Creator Store meshes.
