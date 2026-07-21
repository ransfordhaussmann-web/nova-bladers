# Creator Store Bey Models

Import Creator Store / Sketchfab meshes into Studio under:

`ReplicatedStorage → NovaBladers → Models`

| Model name   | Bey          | Notes                          |
|--------------|--------------|--------------------------------|
| NovaStriker  | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell    | Iron Shell   |                                |
| VoltDash     | Volt Dash    |                                |
| ShadowBite   | Shadow Bite  |                                |
| EmberCore    | Ember Core   |                                |
| FrostCrown   | Frost Crown  |                                |

**Priority:** `BeyModelBuilder` loads Models/ folder first, then `modelAssets.meshId`, then procedural fallback.

To use a Toolbox mesh without importing: paste `rbxassetid://…` into `BeyCatalog.modelAssets.meshId`.
