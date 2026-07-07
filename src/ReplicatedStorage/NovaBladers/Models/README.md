# Bey Models — Studio Import

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Model Name | Bey | Creator Store search terms |
|------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | spinning top, bey blade attack |
| `IronShell` | Iron Shell | beyblade defense, spinning top metal |
| `VoltDash` | Volt Dash | beyblade stamina, lightning top |
| `ShadowBite` | Shadow Bite | beyblade balance, dark spinning top |
| `CrimsonOrbit` | Crimson Orbit | beyblade attack red, fire spinning top |
| `FrostAnchor` | Frost Anchor | beyblade ice, frost spinning top |

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search using `searchTerms` from `BeyCatalog.lua` (e.g. `spinning top`, `bey blade`)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
5. Optional: set `PrimaryPart` or name collision part `Hull`

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D layers.

See also: [docs/BEY-MODELS.md](../../docs/BEY-MODELS.md)
