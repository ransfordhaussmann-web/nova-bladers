# Creator Store Bey Models

Import spinning-top models from the Roblox Creator Store into this folder.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

## Models (9 Beys)

| Model Name   | Bey            | Type     |
|--------------|----------------|----------|
| NovaStriker  | Nova Striker   | Attack   |
| IronShell    | Iron Shell     | Defense  |
| VoltDash     | Volt Dash      | Stamina  |
| ShadowBite   | Shadow Bite    | Balance  |
| CrimsonFang  | Crimson Fang   | Attack   |
| FrostCrown   | Frost Crown    | Defense  |
| SolarCoil    | Solar Coil     | Stamina  |
| BlazeQuill   | Blaze Quill    | Attack   |
| TideAnchor   | Tide Anchor    | Balance  |

## Setup in Studio

1. Toolbox → Creator Store → search "spinning top" (no official IP)
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to match the table above
4. Set PrimaryPart or ensure a `Hull` part exists

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D meshes.

## Optional: meshId shortcut

Set `modelAssets.meshId` in `BeyCatalog.lua` for a direct MeshPart without a full model import.
