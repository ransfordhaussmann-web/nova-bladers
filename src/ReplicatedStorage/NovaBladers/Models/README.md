# Bey Models (optional Creator Store imports)

Procedural models are built at runtime by `BeyModelBuilder`. To use a Creator Store mesh instead:

1. Roblox Studio → Toolbox → **Creator Store**
2. Search the `creatorStoreSearch` term from `BeyCatalog.modelAssets`
3. Insert the model under `ReplicatedStorage → NovaBladers → Models`
4. Rename it to the `studioModelName` (e.g. `CrimsonFang`)
5. Optional: set `modelAssets.meshId` in `BeyCatalog` for a single MeshPart import

| Bey | Studio model name | Toolbox search hint |
|-----|-------------------|---------------------|
| Nova Striker | NovaStriker | Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| Crimson Fang | CrimsonFang | spinning top attack red |
| Granite Fort | GraniteFort | spinning top defense stone |
| Solar Drift | SolarDrift | spinning top stamina orange |
| Phantom Edge | PhantomEdge | spinning top balance cyan |
