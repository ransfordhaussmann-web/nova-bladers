# Bey Models (Studio import)

Place Creator Store or imported 3D models here. `BeyModelBuilder` clones by `modelRef.studioModelName` when present.

| Folder | Bey | Creator Store search hints |
|--------|-----|---------------------------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonOrbit` | Crimson Orbit | `spinning top red`, `fire beyblade`, `attack top 3d` |
| `FrostAnchor` | Frost Anchor | `ice spinning top`, `frost beyblade`, `defense top 3d` |

After import: set `PrimaryPart`, weld parts, optional `Hull` on collision part. Procedural layers are used as fallback when no model is found.
