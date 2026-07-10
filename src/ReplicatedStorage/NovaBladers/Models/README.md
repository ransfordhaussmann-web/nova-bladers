# Bey Models (Creator Store / Studio Import)

Place imported Creator Store models under `ReplicatedStorage → NovaBladers → Models`.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Studio Model Name | Bey | Type |
|-------------------|-----|------|
| NovaStriker | Nova Striker | Attack |
| IronShell | Iron Shell | Defense |
| VoltDash | Volt Dash | Stamina |
| ShadowBite | Shadow Bite | Balance |
| CrimsonBlaze | Crimson Blaze | Attack |
| FrostOrbit | Frost Orbit | Defense |

## Import Options

1. **Studio Models folder** — Import mesh into `Models/<studioModelName>` in Studio.
   Rojo syncs `src/ReplicatedStorage/NovaBladers/Models/` to Studio.

2. **Creator Store meshId** — Set `modelAssets.meshId = "rbxassetid://..."` in `BeyCatalog.lua`
   (Toolbox → Creator Store → spinning top / arena fighter assets).

3. **Procedural fallback** — If no import is found, `BeyModelBuilder` builds a layered 3D model automatically.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of Nova Striker.
