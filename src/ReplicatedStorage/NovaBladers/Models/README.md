# Creator Store / Studio Bey Models

Procedural Bey meshes work out of the box. Optional imported models go here as **Model** instances named after `studioModelName` in `BeyCatalog.modelRef`.

## Supported Beys (6)

| Catalog ID   | Studio folder name | Type    |
|-------------|-------------------|---------|
| NovaStriker | NovaStriker       | Attack  |
| IronShell   | IronShell         | Defense |
| VoltDash    | VoltDash          | Stamina |
| ShadowBite  | ShadowBite        | Balance |
| BlazeOrbit  | BlazeOrbit        | Attack  |
| TitanGuard  | TitanGuard        | Defense |

## Import in Roblox Studio

1. Toolbox → Creator Store → search spinning top / arena fighter meshes (original IP only).
2. Insert mesh, rename to the **Studio folder name** from the table above.
3. Move under `ReplicatedStorage → NovaBladers → Models`.
4. Or set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import.

`BeyModelBuilder` auto-scales imported models to ~3.5 stud diameter and welds them to the physics hull.

## Nova Striker (Sketchfab reference)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of Nova Striker.
