# Nova Bladers — Studio Model Imports

Optional Creator Store / Sketchfab models for in-game use.  
If a model is missing, `BeyModelBuilder` falls back to procedural 3D layers.

## Import locations

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top, ~3.6 studs |
| `CrimsonComet` | Crimson Comet | Red attack bey, flat on arena |
| `FrostCrown` | Frost Crown | Ice defense bey, flat on arena |

## Setup in Studio

1. Import or insert model from Creator Store
2. Rename to match `studioModelName` in `BeyCatalog.lua`
3. Set `PrimaryPart` (or name collision part `Hull`)
4. Rojo sync → model lives in this folder for Git

Tune scale via `modelRef.targetSize` in `BeyCatalog.lua`.
