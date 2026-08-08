Creator Store / imported 3D models for in-game Beys.

Place each model under `ReplicatedStorage/NovaBladers/Models/` with the exact name below.
`BeyModelBuilder` clones from here when present; otherwise procedural layers are used.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| GraniteFort | Granite Fort |
| SolarDrift | Solar Drift |
| PhantomEdge | Phantom Edge |
| CrystalEdge | Crystal Edge |
| BlazeCrown | Blaze Crown |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`
5. Play — `BeyModelBuilder` auto-scales and welds to physics hull

Optional mesh ID fallback: set `modelAssets.meshId` in `BeyCatalog.lua`.
