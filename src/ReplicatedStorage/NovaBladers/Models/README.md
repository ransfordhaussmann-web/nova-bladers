# Bey Model Imports

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostHalo` | Frost Halo |

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store** — search the `creatorStoreSearch` hint in `BeyCatalog.lua`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`

See `docs/BEY-MODELS.md` for meshId and Sketchfab import details.
