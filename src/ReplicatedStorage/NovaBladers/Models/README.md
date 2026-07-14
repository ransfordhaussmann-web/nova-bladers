# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Studio model name | Bey | Search hints (Creator Store) |
|-------------------|-----|------------------------------|
| `NovaStriker` | Nova Striker | Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | spinning top defense, heavy metal top |
| `VoltDash` | Volt Dash | spinning top stamina, flat metal top |
| `ShadowBite` | Shadow Bite | spinning top balance, dark metal top |
| `CrimsonEdge` | Crimson Edge | spinning top fire, red attack top |
| `FrostHalo` | Frost Halo | spinning top ice, crystal defense top |

## Import steps

1. Studio → **Toolbox → Creator Store** → search terms from table above
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move under `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Optional: set `targetSize` / `importRotation` in `BeyCatalog.modelRef`

See `docs/BEY-MODELS.md` for meshId and FBX import alternatives.
