# Bey Model Import Slots

Optional Creator Store / Sketchfab models. Procedural fallbacks work without imports.

| Slot name | Bey | Import path |
|-----------|-----|-------------|
| **NovaStriker** | Nova Striker | `ReplicatedStorage/NovaBladers/Models/NovaStriker` |
| **CrimsonVortex** | Crimson Vortex | `ReplicatedStorage/NovaBladers/Models/CrimsonVortex` |
| **GlacierShield** | Glacier Shield | `ReplicatedStorage/NovaBladers/Models/GlacierShield` |

## Studio steps

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/<SlotName>`
4. Set `PrimaryPart` on collision hull; name collider `Hull` if possible
5. Play — `BeyModelBuilder` clones and scales via `modelRef` in `BeyCatalog.lua`

See also `docs/BEY-MODELS.md` for `modelAssets.meshId` alternative.
