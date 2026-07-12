# Nova Bladers — Creator Store Models

Place imported Creator Store / Toolbox models here as **Model** instances.
`BeyModelBuilder` clones them when `BeyCatalog.modelRef.studioModelName` matches.

## Expected model names

| Bey | Studio model name |
|-----|-------------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Forge | `CrimsonForge` |
| Frost Prism | `FrostPrism` |

## Setup in Roblox Studio

1. Toolbox → Creator Store → search spinning top / arena bey models
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to the `studioModelName` from the table above
4. Optional: set `modelRef.targetSize` or `modelRef.importRotation` in `BeyCatalog.lua`

If no model is found, procedural fallback geometry is used automatically.
