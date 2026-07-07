# Bey Models (Creator Store / Studio Import)

Optional 3D meshes for in-game Beys. Procedural fallbacks exist if no model is imported.

## Import in Roblox Studio

1. Toolbox → Creator Store → search "spinning top" / "beyblade"
2. Import mesh into `ReplicatedStorage → NovaBladers → Models`
3. Name the Model exactly as `studioModelName` in `BeyCatalog.lua`

| Bey | Studio Model Name | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Frost Crown | `FrostCrown` | Ice/defense themed |
| Crimson Forge | `CrimsonForge` | Fire/attack themed |

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` mesh ID.
