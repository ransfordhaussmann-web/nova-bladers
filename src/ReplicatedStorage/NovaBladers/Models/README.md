# Creator Store / Studio Bey Models

Import spinning-top models from the Roblox Creator Store (Toolbox) into this folder.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Model Name   | Bey          | Fallback |
|--------------|--------------|----------|
| NovaStriker  | Nova Striker | Procedural |
| IronShell    | Iron Shell   | Procedural |
| VoltDash     | Volt Dash    | Procedural |
| ShadowBite   | Shadow Bite  | Procedural |
| CrimsonFang  | Crimson Fang | Procedural |
| FrostCrown   | Frost Crown  | Procedural |
| SolarCoil    | Solar Coil   | Procedural |

## Studio Import

1. Toolbox → Creator Store → search "spinning top" (no official IP names)
2. Insert model under `ReplicatedStorage → NovaBladers → Models`
3. Rename to the `studioModelName` from the table above
4. Set PrimaryPart or a `Hull` part for physics welding

If no Studio model is present, `BeyModelBuilder` builds a procedural fallback automatically.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart IDs without a full model.
