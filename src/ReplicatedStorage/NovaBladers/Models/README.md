# Bey Models — Studio Import

Place imported Creator Store or custom 3D models here. Each model folder name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Model folder | Bey | Creator Store search hint |
|---|---|---|
| `NovaStriker` | Nova Striker | `spinning top blue attack` |
| `CrimsonFang` | Crimson Fang | `spinning top red attack` |
| `GraniteFort` | Granite Fort | `spinning top heavy defense` |
| `SolarDrift` | Solar Drift | `spinning top gold stamina` |
| `PhantomEdge` | Phantom Edge | `spinning top phantom balance` |

## Import steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search the hint from the table (or use your own mesh)
3. Insert model into Workspace, resize to ~3–4 studs wide
4. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
5. Set `PrimaryPart` on the collision hull; name it `Hull` if possible

If no Studio model is present, `BeyModelBuilder` falls back to procedural 3D layers automatically.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
