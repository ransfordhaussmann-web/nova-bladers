# Bey 3D Models (optional Creator Store imports)

Place imported spinning-top models here. `BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Folder | Bey |
|--------|-----|
| `NovaStriker` | Nova Striker — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeComet` | Blaze Comet |
| `FrostPrism` | Frost Prism |

## Studio import steps

1. Toolbox → Creator Store → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move under `ReplicatedStorage → NovaBladers → Models → <FolderName>`
4. Set `PrimaryPart` on the collision part, name it `Hull`
5. Rojo sync → Play → pick the bey in Bey-Auswahl

Alternatively, set `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`).
