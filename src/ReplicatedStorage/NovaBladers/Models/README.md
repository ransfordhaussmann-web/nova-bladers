# Creator Store Bey Models (optional)

Procedural 3D models are built at runtime when no Studio import exists.
To use Creator Store / Toolbox meshes instead:

1. Import or insert the model in Roblox Studio
2. Place it under `ReplicatedStorage → NovaBladers → Models`
3. Name it exactly as listed below

| Catalog ID   | Studio model name | Notes                          |
|--------------|-------------------|--------------------------------|
| NovaStriker  | NovaStriker       | See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostPrism   | FrostPrism        | Ice / defense bey              |
| EmberCore    | EmberCore         | Fire / attack bey              |

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from the Toolbox.
