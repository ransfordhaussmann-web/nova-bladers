# Bey Models — Studio Import

Procedural fallbacks exist for all 6 beys. Optional Creator Store / custom meshes improve visuals.

## Import path

After Studio import, place models here:

```
ReplicatedStorage → NovaBladers → Models → <ModelName>
```

| Bey | Model folder name | Notes |
|-----|-------------------|-------|
| Nova Striker | `NovaStriker` | See docs/SKETCHFAB-NOVA-STRIKER.md |
| Crimson Fang | `CrimsonFang` | Attack-type, red fang blades |
| Frost Crown | `FrostCrown` | Defense-type, ice crown |

## How to import from Creator Store

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
5. Set `PrimaryPart` or name collision part `Hull`
6. Rojo sync — `BeyModelBuilder` auto-clones via `modelRef.studioModelName`

## Alternative: meshId in catalog

In `BeyCatalog.lua`, set `modelAssets.meshId` instead of importing a full model:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```
