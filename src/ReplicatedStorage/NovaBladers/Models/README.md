# Creator Store / Studio Models

Place imported 3D models here as **Model** instances. `BeyModelBuilder` clones them when `modelRef.studioModelName` matches.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import (see `docs/SKETCHFAB-NOVA-STRIKER.md`) |
| `IronShell` | Iron Shell | Creator Store / Toolbox spin top |
| `VoltDash` | Volt Dash | Creator Store / Toolbox spin top |
| `ShadowBite` | Shadow Bite | Creator Store / Toolbox spin top |
| `CrimsonBlaze` | Crimson Blaze | Creator Store / Toolbox spin top |
| `FrostCrown` | Frost Crown | Creator Store / Toolbox spin top |

**Path in Studio:** `ReplicatedStorage → NovaBladers → Models → <ModelName>`

If no Studio model is found, procedural layers are built automatically.

**Optional:** set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full model folder.
