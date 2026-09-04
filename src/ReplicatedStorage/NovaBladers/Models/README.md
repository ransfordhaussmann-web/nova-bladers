# Bey Models (Creator Store / Studio Import)

Import Creator Store or custom models into this folder as **Model** instances.
Each Bey's `modelRef.studioModelName` in `BeyCatalog.lua` maps to the model name here.

| Model Name   | Bey           | Notes                          |
|--------------|---------------|--------------------------------|
| NovaStriker  | Nova Striker  | Sketchfab GLB (see docs/)      |
| IronShell    | Iron Shell    | Creator Store spinning top     |
| VoltDash     | Volt Dash     | Creator Store spinning top     |
| ShadowBite   | Shadow Bite   | Creator Store spinning top     |
| CrimsonFang  | Crimson Fang  | Creator Store spinning top     |
| FrostCrown   | Frost Crown   | Creator Store spinning top     |
| SolarCoil    | Solar Coil    | Creator Store spinning top     |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

If no model is present, `BeyModelBuilder` falls back to procedural geometry.
