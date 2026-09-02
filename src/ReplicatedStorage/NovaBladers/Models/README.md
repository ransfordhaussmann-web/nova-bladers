# Bey Model Imports

Procedural 3D models are built at runtime. For higher-quality meshes, import Creator Store models into Studio:

| Studio folder name | Bey | Toolbox search hint |
|--------------------|-----|---------------------|
| `NovaStriker` | Nova Striker | sketchfab / storm pegasus |
| `CrimsonFang` | Crimson Fang | spinning top red attack |
| `GraniteFort` | Granite Fort | spinning top stone defense |
| `SolarDrift` | Solar Drift | spinning top gold sun |
| `PhantomEdge` | Phantom Edge | spinning top silver blade |

## Import steps

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search the hint from the table above
3. Insert model into `ReplicatedStorage → NovaBladers → Models → <Name>`
4. Set `PrimaryPart`, name collision part `Hull`, scale to ~3.5 studs wide
5. Play — `BeyModelBuilder` auto-clones when `modelRef.studioModelName` matches

See `docs/BEY-MODELS.md` for meshId fallback via `modelAssets`.
