# Bey Models (Studio Import)

Place imported Creator Store or custom 3D models here. `BeyModelBuilder` clones by `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonEdge` | Crimson Edge |
| `FrostHalo` | Frost Halo |

## Import steps

1. Studio → **Toolbox → Creator Store** → search `spinning top` (see `searchTerms` in catalog)
2. Scale to ~3.5 studs wide, flat on arena floor
3. Rename model to the name above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Set **PrimaryPart** (or child part named `Hull`)
6. Play — procedural layers are skipped when a matching model exists

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker reference).
