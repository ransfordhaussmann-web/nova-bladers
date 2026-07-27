# Bey Models — Studio Import

Import Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model Name | Bey |
|------------|-----|
| NovaStriker | Nova Striker (Sketchfab ref in catalog) |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| FrostPrism | Frost Prism |
| EmberCore | Ember Core |

## Import steps

1. Roblox Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to match `studioModelName` (e.g. `FrostPrism`)
4. Set `PrimaryPart`, weld parts, optional `Hull` collision part
5. Procedural fallback in `BeyModelBuilder` is used when no model is present

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
