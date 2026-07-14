# Nova Bladers — Studio Model Imports

Optional 3D meshes for Creator Store / Sketchfab imports. Procedural fallbacks exist if no model is present.

| Model name | Bey | Creator Store hint |
|------------|-----|-------------------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeCore | Blaze Core | spinning top fire / flame ring |
| FrostOrbit | Frost Orbit | spinning top ice / crystal crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` with a Creator Store `rbxassetid`.
