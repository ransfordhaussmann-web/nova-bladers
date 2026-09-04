
Import Creator Store or Sketchfab models here for in-game use.

## Studio-Import

After import in Roblox Studio, place models under:
`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Crimson Fang | CrimsonFang |
| Frost Crown | FrostCrown |
| Solar Coil | SolarCoil |

Each BeyCatalog entry has a `modelRef.studioModelName` matching the folder name.
If no Studio model is present, BeyModelBuilder falls back to procedural geometry.

## Optional meshId

Set `modelAssets.meshId` in BeyCatalog for direct rbxassetid meshes from Creator Store.
