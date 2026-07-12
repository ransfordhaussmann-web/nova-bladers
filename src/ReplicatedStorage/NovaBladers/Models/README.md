# Creator Store Models

Import spinning-top models from Roblox Creator Store into Studio, then place them here:

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model Name     | Bey           | Fallback        |
|----------------|---------------|-----------------|
| NovaStriker    | Nova Striker  | Procedural      |
| IronShell      | Iron Shell    | Procedural      |
| VoltDash       | Volt Dash     | Procedural      |
| ShadowBite     | Shadow Bite   | Procedural      |
| CrimsonForge   | Crimson Forge | Procedural      |
| FrostPrism     | Frost Prism   | Procedural      |

Each model is cloned at runtime via `BeyCatalog.modelRef.studioModelName`.
If no model exists, `BeyModelBuilder` builds a procedural fallback automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` to use a MeshPart directly.
