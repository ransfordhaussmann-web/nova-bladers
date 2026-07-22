# Bey Models (Studio import)

Place imported Creator Store / Sketchfab models here as **Model** instances.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonVortex` | Crimson Vortex |
| `FrostPrism` | Frost Prism |

Path after Rojo sync: `ReplicatedStorage → NovaBladers → Models`

## Creator Store workflow

1. Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move under `Models/` with the name from the table above
4. Optional: set `PrimaryPart` and name collision part `Hull`
5. Or paste MeshId into `BeyCatalog.modelAssets` (see `docs/BEY-MODELS.md`)

Procedural 3D layers are used when no Studio model or `meshId` is set.
