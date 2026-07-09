# Creator Store Bey Models

Import spinning-top models from Roblox Studio **Toolbox → Creator Store** (search: spinning top, arena fighter).

Place each imported Model under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Expected model names

| Bey | studioModelName | Fallback |
|-----|-----------------|----------|
| Nova Striker | NovaStriker | Procedural + Sketchfab GLB (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| Iron Shell | IronShell | Procedural heavy shell |
| Volt Dash | VoltDash | Procedural stamina ring |
| Shadow Bite | ShadowBite | Procedural dark fangs |
| Frost Prism | FrostPrism | Procedural ice crystals |
| Blaze Ripper | BlazeRipper | Procedural flame blades |

If no Studio model is found, `BeyModelBuilder` uses procedural visuals automatically.

## Optional: rbxassetid mesh

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a Model folder.

## Scale

Adjust `modelRef.targetSize` in `BeyCatalog.lua` (default ~3.5 studs diameter).
