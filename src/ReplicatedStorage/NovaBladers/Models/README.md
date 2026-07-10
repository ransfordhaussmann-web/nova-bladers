# Bey Studio Models

Optional 3D imports for in-game Bey visuals. Procedural fallbacks exist if no model is present.

| Model name   | Bey          | Import notes                          |
|--------------|--------------|---------------------------------------|
| NovaStriker  | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md`  |
| CrimsonFang  | Crimson Fang | Creator Store / custom GLB in Studio  |
| GlacierSpin  | Glacier Spin | Creator Store / custom GLB in Studio  |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store meshId (alternative)

Set `modelAssets.meshId` in `BeyCatalog.lua` with a Toolbox asset id (`rbxassetid://…`).
Search Roblox Studio Toolbox → Creator Store → "spinning top".
