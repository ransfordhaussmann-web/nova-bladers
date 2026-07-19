# Bey Models (Creator Store / Studio Import)

Place imported Creator Store or Sketchfab models here as **Model** instances.
`BeyModelBuilder` loads them automatically when `modelRef.studioModelName` matches.

| Model name   | Bey          | Notes                                      |
|--------------|--------------|--------------------------------------------|
| NovaStriker  | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md`       |
| CrimsonFang  | Crimson Fang | Toolbox → spinning top / attack bey        |
| FrostHalo    | Frost Halo   | Toolbox → ice / stamina bey                |

**Fallback:** If no model is present, procedural geometry is used.

**Optional:** Set `modelAssets.meshId` in `BeyCatalog.lua` for rbxassetid meshes.
