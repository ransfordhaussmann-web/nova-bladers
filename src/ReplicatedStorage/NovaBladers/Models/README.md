# Bey Model Imports

Optional Creator Store / Sketchfab models for higher-quality visuals.
Procedural fallbacks exist for all beys when no Studio model is present.

## Studio import paths

| Model name | Bey | Path |
|------------|-----|------|
| **NovaStriker** | Nova Striker | `ReplicatedStorage/NovaBladers/Models/NovaStriker` |
| **CrimsonVortex** | Crimson Vortex | `ReplicatedStorage/NovaBladers/Models/CrimsonVortex` |
| **FrostCrown** | Frost Crown | `ReplicatedStorage/NovaBladers/Models/FrostCrown` |

## How to import

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid official IP names)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Move under `ReplicatedStorage/NovaBladers/Models/<ModelName>`
5. Set `PrimaryPart` on the collision hull; name it `Hull` if possible
6. Optional: paste `MeshId` into `BeyCatalog.modelAssets.meshId` for that bey

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md`.
