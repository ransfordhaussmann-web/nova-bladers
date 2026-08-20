# Bey Models — Studio Import Slots

Place imported Creator Store or custom 3D models here. Each bey checks for a matching folder name before falling back to procedural geometry.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

## How to import

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. **File → Import 3D** or drag into `ReplicatedStorage/NovaBladers/Models/<BeyId>`
4. Name the model exactly as in the table above
5. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead (skips procedural layers)

See `docs/BEY-MODELS.md` for full setup guide.
