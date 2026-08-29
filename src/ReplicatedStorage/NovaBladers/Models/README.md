# Bey Models (Studio Import)

Procedural models are built at runtime. Optional Creator Store / Sketchfab imports go here as **Model** instances named after `studioModelName` in `BeyCatalog.lua`.

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.

Path: `ReplicatedStorage → NovaBladers → Models → NovaStriker`

## Creator Store Beys (optional)

Search Roblox Studio **Toolbox → Creator Store** using the `creatorStore.searchTerms` from each catalog entry, then import and rename:

| Model name   | Catalog id    | Suggested search        |
|-------------|---------------|-------------------------|
| CrimsonFang | CrimsonFang   | attack blade, red top   |
| GraniteFort | GraniteFort   | heavy top, stone top    |
| SolarDrift  | SolarDrift    | gold top, sun top       |
| PhantomEdge | PhantomEdge   | ghost top, cyan blade   |
| CrystalEdge | CrystalEdge   | crystal top, ice shard  |
| BlazeCrown  | BlazeCrown    | fire top, crown top     |

After import, set `modelAssets.meshId` in `BeyCatalog.lua` if using a MeshPart asset id instead of a cloned Model.
