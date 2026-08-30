# Bey Models (optional Creator Store imports)

Procedural models are built automatically in `BeyModelBuilder.lua`.
To use Creator Store meshes instead, import a model into this folder
or set `modelAssets.meshId` in `BeyCatalog.lua`.

## Studio import

1. Toolbox → Creator Store → search per `modelAssets.creatorStoreSearch` in catalog
2. Import mesh as a **Model** under `ReplicatedStorage/NovaBladers/Models/`
3. Name the model exactly like the Bey `id` (e.g. `CrimsonFang`)
4. Optional: set `modelAssets.meshId` to `rbxassetid://...` for MeshPart-only imports

## Current catalog (8 Beys)

| id | Creator Store search hint |
|----|---------------------------|
| NovaStriker | Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | spinning top defense green |
| VoltDash | spinning top yellow stamina |
| ShadowBite | spinning top purple balance |
| CrimsonFang | spinning top red attack |
| GraniteFort | spinning top stone defense |
| SolarDrift | spinning top gold stamina |
| PhantomEdge | spinning top phantom balance |
