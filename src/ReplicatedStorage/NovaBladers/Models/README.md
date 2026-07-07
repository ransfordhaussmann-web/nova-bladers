# Bey Models (Creator Store / Studio Import)

Place imported Creator Store models here as **Model** instances named after `modelRef.studioModelName` in `BeyCatalog.lua`.

| Studio Name   | Bey           | Creator Store search terms (see catalog) |
|---------------|---------------|------------------------------------------|
| NovaStriker   | Nova Striker  | spinning top attack, beyblade pegasus    |
| IronShell     | Iron Shell    | spinning top defense, beyblade shield    |
| VoltDash      | Volt Dash     | spinning top stamina, beyblade lightning |
| ShadowBite    | Shadow Bite   | spinning top balance, beyblade dark      |
| CrimsonOrbit  | Crimson Orbit | spinning top fire, beyblade attack red   |
| FrostAnchor   | Frost Anchor  | spinning top ice, beyblade defense blue  |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search using `searchTerms` from `BeyCatalog.lua`
2. Insert mesh into `ReplicatedStorage → NovaBladers → Models`
3. Rename model to match `studioModelName` (e.g. `CrimsonOrbit`)
4. Optional: set `modelAssets.meshId` in catalog for direct MeshPart fallback

Procedural fallbacks render automatically when no Studio model is present.
