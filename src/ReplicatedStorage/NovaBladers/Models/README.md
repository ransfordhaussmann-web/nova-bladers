# Nova Bladers — Studio Model Imports

Place Creator Store or imported 3D models here for in-game use.
Procedural fallback builds automatically when a model is missing.

| Model Name   | Bey           | Notes |
|--------------|---------------|-------|
| NovaStriker  | Nova Striker  | Sketchfab GLB import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell    | Iron Shell    | Creator Store spinning top |
| VoltDash     | Volt Dash     | Creator Store spinning top |
| ShadowBite   | Shadow Bite   | Creator Store spinning top |
| CrimsonFang  | Crimson Fang  | Creator Store spinning top |
| NeonPulse    | Neon Pulse    | Creator Store spinning top |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox mesh IDs.
