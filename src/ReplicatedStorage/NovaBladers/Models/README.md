# Bey 3D Models (Studio Import)

Optional Creator Store / Sketchfab models for in-game Beys.

## Model folders

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostOrbit | Frost Orbit |

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Alternatives

1. **Studio Models folder** — import GLB/mesh and name the Model as above (`modelRef.studioModelName`).
2. **Toolbox meshId** — set `modelAssets.meshId` in `BeyCatalog.lua` (`rbxassetid://…`).
3. **Procedural fallback** — if neither exists, `BeyModelBuilder` builds a layered 3D Bey automatically.

See `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker GLB import.
