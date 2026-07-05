# Bey Studio Models

Optional Creator Store / imported models for in-game use. Procedural fallbacks exist if a model is missing.

Place each model under `ReplicatedStorage → NovaBladers → Models`:

| Model name     | Bey            | Notes                                      |
|----------------|----------------|--------------------------------------------|
| NovaStriker    | Nova Striker   | See `docs/SKETCHFAB-NOVA-STRIKER.md`       |
| IronShell      | Iron Shell     | Toolbox import or procedural fallback      |
| VoltDash       | Volt Dash      | Toolbox import or procedural fallback      |
| ShadowBite     | Shadow Bite    | Toolbox import or procedural fallback      |
| CrimsonBlaze   | Crimson Blaze  | Toolbox import or procedural fallback      |
| FrostOrbit     | Frost Orbit    | Toolbox import or procedural fallback      |

## Creator Store meshId (optional)

In `BeyCatalog.lua`, set `modelAssets.meshId` to an `rbxassetid://…` from Roblox Studio Toolbox → Creator Store (e.g. spinning top meshes). Procedural builders are used when no Studio model or meshId is present.
