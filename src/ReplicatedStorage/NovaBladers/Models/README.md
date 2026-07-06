# Bey Models (Creator Store / Studio Import)

Import spinning-top models from Roblox Creator Store into Studio under:

`ReplicatedStorage → NovaBladers → Models`

## Expected model names

| Catalog ID   | Studio folder name |
|-------------|-------------------|
| NovaStriker | NovaStriker       |
| IronShell   | IronShell         |
| VoltDash    | VoltDash          |
| ShadowBite  | ShadowBite        |
| CrimsonBlaze| CrimsonBlaze      |
| FrostOrbit  | FrostOrbit        |

If no Studio model exists, procedural meshes are built automatically.

## Alternative: meshId in catalog

Set `modelAssets.meshId` in `BeyCatalog.lua` (rbxassetid) for a single MeshPart import without a full Model folder.
