# Creator Store Bey Models

Import optional 3D models from Roblox Studio Toolbox → Creator Store (search: spinning top, arena fighter).

Place each imported Model under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Roster (6 Beys)

| Bey ID | Studio Model Name | Type |
|--------|-------------------|------|
| NovaStriker | NovaStriker | Attack |
| IronShell | IronShell | Defense |
| VoltDash | VoltDash | Stamina |
| ShadowBite | ShadowBite | Balance |
| CrimsonRipper | CrimsonRipper | Attack |
| FrostWard | FrostWard | Defense |

Without a Studio import, `BeyModelBuilder.lua` builds procedural fallbacks automatically.

## Optional Toolbox mesh

Set `modelAssets.meshId` in `BeyCatalog.lua` to an `rbxassetid://` mesh ID for a single MeshPart fallback.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import steps.
