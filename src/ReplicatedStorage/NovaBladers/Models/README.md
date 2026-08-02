# Bey Models (Creator Store / Studio Import)

Import Creator Store spinning-top models into `ReplicatedStorage → NovaBladers → Models`.

| Model Name     | Bey            | Notes                          |
|----------------|----------------|--------------------------------|
| NovaStriker    | Nova Striker   | Sketchfab GLB (see docs/)      |
| IronShell      | Iron Shell     | Creator Store or procedural    |
| VoltDash       | Volt Dash      | Creator Store or procedural    |
| ShadowBite     | Shadow Bite    | Creator Store or procedural    |
| CrystalFang    | Crystal Fang   | Creator Store or procedural    |
| GraniteCrush   | Granite Crush  | Creator Store or procedural    |
| EmberOrbit     | Ember Orbit    | Creator Store or procedural    |

## Setup

1. Roblox Studio → Toolbox → Creator Store → search "spinning top" / "beyblade"
2. Insert model into `ReplicatedStorage.NovaBladers.Models`
3. Rename to match `studioModelName` in `BeyCatalog.lua`
4. Without a Studio model, procedural fallback builds automatically

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox mesh IDs.
