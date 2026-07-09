# Bey Models (Studio Import)

Optional Creator Store models for in-game use. Procedural fallbacks exist if no model is imported.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Toolbox → Creator Store → spinning top |
| `FrostHalo` | Frost Halo | Toolbox → Creator Store → spinning top |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Optional: paste `rbxassetid` into `modelAssets.meshId` for MeshPart loading without Studio clone.
