
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store Beys (optional mesh import)

Search Roblox Studio Toolbox → Creator Store, then import as Model under this folder:

| Model Name   | Creator Store Search Hint        |
|--------------|----------------------------------|
| CrimsonFang  | spinning top red blade           |
| GraniteFort  | spinning top stone shield        |
| SolarDrift   | spinning top golden sun          |
| PhantomEdge  | spinning top cyan phantom        |

Procedural fallback models are built automatically if no Studio model is present.
Paste `rbxassetid://` mesh IDs into `BeyCatalog.modelAssets.meshId` for MeshPart fallback.
