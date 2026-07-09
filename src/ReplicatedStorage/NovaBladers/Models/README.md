# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones them automatically when `modelRef.studioModelName` matches.

## Folder layout

| Model name | Bey | Type |
|------------|-----|------|
| `NovaStriker` | Nova Striker | Attack |
| `IronShell` | Iron Shell | Defense |
| `VoltDash` | Volt Dash | Stamina |
| `ShadowBite` | Shadow Bite | Balance |
| `FrostPrism` | Frost Prism | Defense |
| `BlazeRipper` | Blaze Ripper | Attack |

## How to import (Studio)

1. **View → Toolbox → Creator Store** — search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — procedural fallback is used if model is missing

## Alternative: meshId

In `BeyCatalog.lua`, set `modelAssets.meshId` instead of importing a full model.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
