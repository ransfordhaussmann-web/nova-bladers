# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox (Creator Store) into this folder.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Model Name   | Bey           | Fallback        |
|--------------|---------------|-----------------|
| NovaStriker  | Nova Striker  | Procedural      |
| IronShell    | Iron Shell    | Procedural      |
| VoltDash     | Volt Dash     | Procedural      |
| ShadowBite   | Shadow Bite   | Procedural      |
| CrimsonBlaze | Crimson Blaze | Procedural      |
| FrostCrown   | Frost Crown   | Procedural      |

## Import Steps

1. Studio Toolbox → Creator Store → search "spinning top" (no official IP names)
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to the `studioModelName` from the table above
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshPart loading

`BeyModelBuilder` tries Models folder first, then `modelAssets.meshId`, then procedural geometry.
