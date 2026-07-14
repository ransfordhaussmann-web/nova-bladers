# Bey Models — Studio Import Folder

Place imported Creator Store or Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| Model Name | Bey | Search Terms (Toolbox) |
|------------|-----|------------------------|
| NovaStriker | Nova Striker | beyblade attack, spinning top pegasus |
| IronShell | Iron Shell | beyblade defense, spinning top metal |
| VoltDash | Volt Dash | beyblade stamina, spinning top yellow |
| ShadowBite | Shadow Bite | beyblade balance, spinning top dark |
| CrimsonEdge | Crimson Edge | beyblade attack red, spinning top flame |
| FrostHalo | Frost Halo | beyblade ice, spinning top frost |

## Import Steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using `searchTerms` from `BeyCatalog.lua`
3. Insert model into Workspace, scale/orient flat (~3.5 stud diameter)
4. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
5. Set `PrimaryPart` or name collision part `Hull`

Procedural fallback builds automatically when no Studio model is found.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
