# Bey Models (Studio Import)

Place imported Creator Store / Toolbox models here as child Models under `ReplicatedStorage/NovaBladers/Models/`.

| Model name   | Bey          | Notes                                      |
|--------------|--------------|--------------------------------------------|
| NovaStriker  | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeOrbit   | Blaze Orbit  | Optional Creator Store mesh                |
| FrostCoil    | Frost Coil   | Optional Creator Store mesh                |

## Creator Store workflow

1. Roblox Studio → Toolbox → Creator Store → search "spinning top"
2. Insert model into `ReplicatedStorage/NovaBladers/Models/` and rename to match `modelRef.studioModelName`
3. **Or** paste the mesh `rbxassetid` into `BeyCatalog.modelAssets.meshId` for that Bey

`BeyModelBuilder` priority: Models/ folder → `modelAssets.meshId` → procedural fallback.
