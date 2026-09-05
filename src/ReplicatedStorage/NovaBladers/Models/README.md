# Creator Store Bey Models

Optional 3D imports for Nova Bladers. Procedural fallbacks work without these.

## Studio Import

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Model Name   | Bey         | Notes                          |
|--------------|-------------|--------------------------------|
| NovaStriker  | Nova Striker| See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostPrism   | Frost Prism | Ice/defense spinning top       |
| EmberCore    | Ember Core  | Fire/attack spinning top       |

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade" (rename to Nova Bladers IP in-game).

## meshId Alternative

Set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import instead of a full Model.
