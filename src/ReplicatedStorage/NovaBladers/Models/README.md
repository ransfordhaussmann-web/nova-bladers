# Bey 3D Models (Creator Store / Import)

Optional imported meshes live here. If a model folder exists, `BeyModelBuilder` clones it instead of the procedural build.

| Studio folder | Bey | Toolbox search hints |
|---------------|-----|----------------------|
| `NovaStriker` | Nova Striker | spinning top, attack |
| `IronShell` | Iron Shell | spinning top, metal defense |
| `VoltDash` | Volt Dash | spinning top, electric stamina |
| `ShadowBite` | Shadow Bite | spinning top, dark balance |
| `CrimsonFang` | Crimson Fang | spinning top, attack blade |
| `GlacierCore` | Glacier Core | spinning top, ice stamina |

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search with the hints above (or import your own GLB via **File → Import 3D**)
3. Scale to ~3.5 studs wide, flat on the arena floor
4. Rename the model to the **Studio folder** name (e.g. `CrimsonFang`)
5. Move to `ReplicatedStorage → NovaBladers → Models → <Name>`
6. Set **PrimaryPart** (or child part named `Hull`)
7. **Play** — the game auto-clones this mesh

Without an imported model, each bey uses its procedural layered build from `BeyModelBuilder.lua`.

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from a mesh part.
