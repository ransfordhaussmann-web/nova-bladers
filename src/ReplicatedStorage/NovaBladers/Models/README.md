# Nova Bladers — Creator Store Model Import

Place imported Creator Store / Toolbox models here as child **Models** of this folder.

## Nova Striker (Sketchfab)

Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.

After Studio import: `ReplicatedStorage → NovaBladers → Models → NovaStriker`

## Creator Store Beys (Toolbox import)

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade" (generic models).

| Model name     | Bey ID        | Notes              |
|----------------|---------------|--------------------|
| IronShell      | IronShell     | Defense shell      |
| VoltDash       | VoltDash      | Stamina ring       |
| ShadowBite     | ShadowBite    | Balance dark       |
| CrystalFang    | CrystalFang   | Crystal attack     |
| GraniteCrush   | GraniteCrush  | Stone defense      |
| EmberOrbit     | EmberOrbit    | Fire stamina       |

Model name must match `studioModelName` in `BeyCatalog.lua`. Without a Studio model, procedural fallback visuals are used automatically.

Optional: set `modelAssets.meshId` in BeyCatalog for direct Toolbox mesh IDs instead of a full model.
