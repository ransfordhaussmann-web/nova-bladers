# Nova Bladers — Imported 3D Models

Place Creator Store or imported models here. `BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store → search `spinning top` / `bey blade metal` |
| `VoltDash` | Volt Dash | Flat stamina ring models work best |
| `ShadowBite` | Shadow Bite | Dark / asymmetric blade meshes |
| `CrimsonViper` | Crimson Viper | Attack blades, red accent |
| `FrostCrown` | Frost Crown | Crown / ice crystal meshes |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** → insert a spin-top model
2. Scale to ~**3.5 studs** wide, flat on the arena floor
3. Rename to the **Studio model name** from the table above
4. Move to `ReplicatedStorage → NovaBladers → Models → <Name>`
5. Set **PrimaryPart** (or child part named `Hull`)
6. Play — the game auto-clones instead of the procedural build

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full model folder.
