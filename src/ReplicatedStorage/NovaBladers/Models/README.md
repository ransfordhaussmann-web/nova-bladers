# Nova Bladers — Studio Model Slots

Place imported Creator Store or Sketchfab models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonForge` | Crimson Forge |
| `FrostPrism` | Frost Prism |

## Import steps

1. Studio → Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Play — `BeyModelBuilder` clones the model; procedural layers are skipped

Without a Studio model, procedural 3D layers are built automatically.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
