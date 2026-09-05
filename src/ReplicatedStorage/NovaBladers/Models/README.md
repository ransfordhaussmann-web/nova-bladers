
Optional Creator Store / Sketchfab imports for in-game Bey meshes.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| NovaStriker | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostPrism | Frost Prism | Toolbox → Creator Store → spinning top |
| EmberCore | Ember Core | Toolbox → Creator Store → spinning top |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`

Procedural fallbacks in `BeyModelBuilder` are used when no model is present.
Optional: set `modelAssets.meshId` in `BeyCatalog` for direct MeshPart assets.
