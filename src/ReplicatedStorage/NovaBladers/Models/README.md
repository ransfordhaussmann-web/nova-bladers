# Creator Store Model Imports

Place imported 3D models here as **Model** instances matching each Bey's `studioModelName` in `BeyCatalog.lua`.

Path: `ReplicatedStorage → NovaBladers → Models`

## Supported Bey models (8)

| studioModelName | Bey |
|-----------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `StarfallEdge` | Starfall Edge |
| `StoneHalo` | Stone Halo |
| `ThunderCoil` | Thunder Coil |
| `NightMaw` | Night Maw |

## Import from Creator Store

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `spin top`, `metal top` (avoid trademarked names)
3. Insert model into Workspace, resize to ~3–4 studs wide
4. Move to this folder and rename to the `studioModelName` above
5. Set **PrimaryPart** on the collision hull; name the hull part `Hull` if possible

## Import via meshId (no Studio model)

In `BeyCatalog.lua`, set `modelAssets.meshId` to your `rbxassetid://…` value. Procedural layers are skipped when a mesh is set.

## Fallback

If no Studio model or meshId is present, `BeyModelBuilder` builds a procedural layered 3D model at runtime.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import. After Studio import: `ReplicatedStorage → NovaBladers → Models → NovaStriker`
