# Creator Store Model Slots

Place imported Creator Store or custom 3D models here as **Model** instances.
`BeyModelBuilder` clones by `studioModelName` from `BeyCatalog.modelRef`.

| Studio folder name | Bey |
|--------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `GraniteFort` | Granite Fort |
| `SolarDrift` | Solar Drift |
| `PhantomEdge` | Phantom Edge |

## Import in Studio

1. **View → Toolbox → Creator Store** — search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move under `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`), weld mesh parts
5. Play — procedural layers are skipped when a matching folder model exists

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`).

Procedural 3D builders in `BeyModelBuilder.lua` are the fallback when no Studio model is present.
