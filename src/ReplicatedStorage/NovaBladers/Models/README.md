Import Creator Store / Sketchfab models here as child Models:

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeVortex | Blaze Vortex | Toolbox spinning top → `modelAssets.meshId` in BeyCatalog |
| FrostAnchor | Frost Anchor | Toolbox spinning top → `modelAssets.meshId` in BeyCatalog |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<studioModelName>`

Procedural fallback in `BeyModelBuilder` when no Studio model or meshId is set.
