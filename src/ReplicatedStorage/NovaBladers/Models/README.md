# Bey Models — Studio Import Folder

Place Creator Store or imported 3D models here. `BeyModelBuilder` clones by `modelRef.studioModelName` from `BeyCatalog.lua`.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `EmberLance` | Ember Lance | Creator Store spinning top |
| `CrystalTide` | Crystal Tide | Creator Store spinning top |

## Import steps (Studio)

1. **Toolbox → Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — procedural fallback runs if model is missing

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of folder import.
