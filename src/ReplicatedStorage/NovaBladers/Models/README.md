
Import Creator Store / custom 3D models here for in-game use.

Each bey entry in `BeyCatalog.lua` has a `modelRef.studioModelName` — place a Model with that exact name in this folder.

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

## How to import (Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Rename to the **studioModelName** from the table above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Set **PrimaryPart** (or child named `Hull`)
6. Play — game auto-clones this model instead of the procedural fallback

See `docs/BEY-MODELS.md` for meshId and Blender import options.
