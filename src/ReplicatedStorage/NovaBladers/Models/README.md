# Creator Store Bey Models

Optional 3D models imported in Roblox Studio. Without import, procedural builders in `BeyModelBuilder.lua` are used.

## Import path

`ReplicatedStorage → NovaBladers → Models → <BeyId>`

| Bey ID | Studio model name |
|--------|-------------------|
| NovaStriker | NovaStriker |
| IronShell | IronShell |
| VoltDash | VoltDash |
| ShadowBite | ShadowBite |
| CrimsonRipper | CrimsonRipper |
| FrostWard | FrostWard |

## Toolbox import

1. Roblox Studio → Toolbox → Creator Store → search "spinning top" / "arena top"
2. Drag model into `Models/` folder, rename to match `studioModelName` in `BeyCatalog.lua`
3. Or set `modelAssets.meshId` in `BeyCatalog.lua` with `rbxassetid://...`

Models are auto-scaled to ~3.5 stud diameter on spawn.
