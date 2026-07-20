# Creator Store / Studio Models

Import spinning-top meshes from Roblox Creator Store (Toolbox) or Sketchfab GLB.

## Priority (BeyModelBuilder)

1. `Models/<studioModelName>` folder in Studio (from `modelRef.studioModelName`)
2. `modelAssets.meshId` in BeyCatalog (rbxassetid from Toolbox)
3. Procedural fallback (no assets required)

## Supported imports

| Bey | Studio model name | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| Crimson Fang | `CrimsonFang` | Creator Store mesh → `ReplicatedStorage/NovaBladers/Models/CrimsonFang` |
| Frost Halo | `FrostHalo` | Creator Store mesh → `ReplicatedStorage/NovaBladers/Models/FrostHalo` |

## Toolbox setup

1. Roblox Studio → Toolbox → Creator Store → search "spinning top"
2. Insert mesh, copy `MeshId` rbxassetid
3. Uncomment `modelAssets` in `BeyCatalog.lua` and paste the id

After Studio import: **ReplicatedStorage → NovaBladers → Models → &lt;BeyId&gt;**
