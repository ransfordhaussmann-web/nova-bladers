# Bey Models — Studio Import

Optional Creator Store / Toolbox models for in-game use.

## Import path

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName |
|-----|-----------------|
| Nova Striker | NovaStriker |
| Iron Shell | IronShell |
| Volt Dash | VoltDash |
| Shadow Bite | ShadowBite |
| Blaze Wheel | BlazeWheel |
| Frost Veil | FrostVeil |

## Priority (BeyModelBuilder)

1. Clone from `Models/` folder (if present)
2. `modelAssets.meshId` in BeyCatalog (Toolbox mesh)
3. Procedural fallback builder

## Creator Store workflow

1. Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `Models/<studioModelName>`, set PrimaryPart
4. Or copy MeshId into `BeyCatalog.modelAssets.meshId`

See also: `docs/BEY-MODELS.md`
