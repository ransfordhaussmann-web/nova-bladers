# Nova Bladers — Creator Store Models

Import optional 3D models from Roblox Studio Toolbox → Creator Store.

| Studio folder | Bey | Notes |
|---------------|-----|-------|
| `Models/NovaStriker` | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `Models/FrostCrown` | Frost Crown | Ice/defense bey — procedural fallback if missing |
| `Models/EmberFang` | Ember Fang | Fire/attack bey — procedural fallback if missing |

After Studio import: **ReplicatedStorage → NovaBladers → Models → &lt;ModelName&gt;**

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import.
