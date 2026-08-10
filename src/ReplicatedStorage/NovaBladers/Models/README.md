# Nova Bladers — Imported Bey Models

Optional Creator Store / Sketchfab models for in-game Bey visuals.

## Import paths

After Studio import, place models under:

`ReplicatedStorage → NovaBladers → Models → [ModelName]`

| Catalog ID     | Studio model name | Notes |
|----------------|-------------------|-------|
| NovaStriker    | NovaStriker       | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| IronShell      | IronShell         | Creator Store spinning-top mesh |
| VoltDash       | VoltDash          | Creator Store spinning-top mesh |
| ShadowBite     | ShadowBite        | Creator Store spinning-top mesh |
| CrimsonRipper  | CrimsonRipper     | Creator Store spinning-top mesh |
| FrostMonarch   | FrostMonarch      | Creator Store spinning-top mesh |

## Creator Store meshId (alternative)

Set `modelAssets.meshId` in `BeyCatalog.lua` with a Toolbox rbxassetid instead of importing a full model.

Search Roblox Studio Toolbox → Creator Store → "spinning top" (generic assets only — no official IP).

## Fallback

If no Studio model and no meshId are set, `BeyModelBuilder` builds a procedural layered Bey for each catalog entry.
