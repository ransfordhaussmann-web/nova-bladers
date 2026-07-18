# Nova Bladers — Creator Store Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| CrimsonFang | Crimson Fang | Optional Creator Store mesh |
| FrostHalo | Frost Halo | Optional Creator Store mesh |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` with an rbxassetid from Creator Store.
Procedural fallback models are built automatically when no import is found.
