# Studio Model Slots (Creator Store / Import)

Place imported Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Folder name | Bey | Notes |
|-------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `CrimsonFang` | Crimson Fang | Creator Store spinning top |
| `FrostRing` | Frost Ring | Creator Store spinning top |

If a folder is missing, `BeyModelBuilder` falls back to procedural 3D layers.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox mesh IDs without a Studio folder.
