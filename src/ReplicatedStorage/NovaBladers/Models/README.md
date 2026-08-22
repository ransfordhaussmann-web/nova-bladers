# Creator Store Model Imports

Place imported spinning-top models here for in-game use.
Procedural fallbacks exist for every bey if no model is present.

| Model name | Bey | Creator Store search |
|------------|-----|----------------------|
| `NovaStriker` | Nova Striker | spinning top attack blue |
| `IronShell` | Iron Shell | spinning top defense green |
| `VoltDash` | Volt Dash | spinning top yellow stamina |
| `ShadowBite` | Shadow Bite | spinning top dark purple |
| `CrimsonForge` | Crimson Forge | spinning top metal red |
| `FrostCrown` | Frost Crown | spinning top ice blue |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search the query from `BeyCatalog.modelRef.creatorStoreQuery`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Rojo sync pushes changes to Git

See `docs/BEY-MODELS.md` for full setup guide.
