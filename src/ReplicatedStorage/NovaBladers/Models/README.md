
Optional Creator Store / Sketchfab imports for in-game Bey models.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| NovaStriker | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeWheel | Blaze Wheel | Toolbox → Creator Store → spinning top |
| FrostVeil | Frost Veil | Toolbox → Creator Store → ice / crystal top |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`

Procedural fallbacks are built automatically when no model is present.
Alternatively set `modelAssets.meshId` in BeyCatalog.lua with an rbxassetid.
