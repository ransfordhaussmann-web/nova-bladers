# Nova Bladers — Studio Model Imports

Place Creator Store or imported 3D models here. Each bey entry in `BeyCatalog.lua` has a `modelRef.studioModelName` that maps to a child Model in this folder.

If a Studio model is present, `BeyModelBuilder` clones and scales it (~3.5 stud diameter). Otherwise procedural layers are used as fallback.

## Import path

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## All Beys

| studioModelName | Bey | Type |
|-----------------|-----|------|
| NovaStriker | Nova Striker | Attack |
| IronShell | Iron Shell | Defense |
| VoltDash | Volt Dash | Stamina |
| ShadowBite | Shadow Bite | Balance |
| CrimsonFang | Crimson Fang | Attack |
| GraniteFort | Granite Fort | Defense |
| SolarDrift | Solar Drift | Stamina |
| PhantomEdge | Phantom Edge | Balance |
| CrystalEdge | Crystal Edge | Attack |
| BlazeCrown | Blaze Crown | Balance |

## How to import

1. Roblox Studio → Toolbox → Creator Store → search `spinning top` / `bey`
2. Insert model into Workspace, resize to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart` (or name collision part `Hull`)
5. Rojo sync or copy into Studio

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
