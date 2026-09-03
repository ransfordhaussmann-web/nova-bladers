
Import optional Creator Store meshes here for in-game use.

| Model | Catalog ID | Notes |
|-------|------------|-------|
| NovaStriker | NovaStriker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeWheel | BlazeWheel | Creator Store mesh (optional) |
| FrostVeil | FrostVeil | Creator Store mesh (optional) |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`

Procedural fallbacks are built automatically when no mesh is present.
Optional: set `modelAssets.meshId` in BeyCatalog from Studio Toolbox.
