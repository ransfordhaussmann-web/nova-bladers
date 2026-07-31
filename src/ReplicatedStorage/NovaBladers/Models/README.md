# Bey Studio Models (optional Creator Store imports)

Place imported Creator Store / Toolbox models here as **Model** instances. Procedural fallbacks run when a folder entry is missing.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonVortex` | Crimson Vortex | Creator Store spin top (~3.5 stud diameter) |
| `FrostCrown` | Frost Crown | Creator Store spin top (~3.5 stud diameter) |

## Studio import steps

1. **View → Toolbox → Creator Store** — search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage → NovaBladers → Models`
4. Rename to match `studioModelName` in `BeyCatalog.lua` (e.g. `CrimsonVortex`)
5. Rojo sync — in-game `BeyModelBuilder` clones and welds to the physics hull

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a Studio model folder.
