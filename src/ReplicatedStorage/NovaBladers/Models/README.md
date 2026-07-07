# Bey 3D Models (Creator Store / Studio Import)

Optional imported meshes live here as `Model` instances under `ReplicatedStorage/NovaBladers/Models/`.

## Supported slots

| Studio model name | Bey | Fallback |
|-------------------|-----|----------|
| `NovaStriker` | Nova Striker | Procedural |
| `CrimsonFlare` | Crimson Flare | Procedural |
| `FrostCrown` | Frost Crown | Procedural |

## Import options

1. **Studio Models folder** — Import mesh in Studio → name model `CrimsonFlare` or `FrostCrown` → place here.
2. **Creator Store meshId** — Toolbox → Creator Store → spinning top → copy `rbxassetid` into `BeyCatalog.modelAssets.meshId` for the Bey.

Procedural builders in `BeyModelBuilder.lua` are used when no import is present.
