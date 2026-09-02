# Bey Models — Studio Import

Procedural 3D models are built at runtime. Optional Creator Store / custom models go here.

## Import path

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model folder | Bey | Creator Store search hint |
|--------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | storm pegasus spinning top |
| `CrimsonFang` | Crimson Fang | spinning top red attack |
| `GraniteFort` | Granite Fort | spinning top defense stone |
| `SolarDrift` | Solar Drift | spinning top gold stamina |
| `PhantomEdge` | Phantom Edge | spinning top phantom balance |

## Steps (Studio)

1. **View → Toolbox → Creator Store** — search using hint above
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
4. Set `PrimaryPart`, optional `Hull` on collision part
5. Rojo sync — game auto-clones via `BeyModelBuilder.tryCloneStudioModel`

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker GLB).
