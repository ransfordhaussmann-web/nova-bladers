# Bey Models (Studio Import)

Optional Creator Store / imported 3D models for in-game Beys.
Procedural fallbacks exist if no model is found.

## Expected model names (ReplicatedStorage → NovaBladers → Models)

| Bey ID       | Studio Model Name |
|--------------|-------------------|
| NovaStriker  | NovaStriker       |
| IronShell    | IronShell         |
| VoltDash     | VoltDash          |
| ShadowBite   | ShadowBite        |
| CrimsonBlaze | CrimsonBlaze      |
| FrostOrbit   | FrostOrbit        |

## Import options

1. **Studio Models folder** — Import GLB/mesh under `Models/<studioModelName>` in Studio.
2. **Creator Store meshId** — Set `modelAssets.meshId` in `BeyCatalog.lua` (rbxassetid).

See `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker Sketchfab import.
