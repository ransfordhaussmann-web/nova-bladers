# Bey 3D Models (Studio Import)

Place imported Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model name | Bey | Creator Store search hints |
|------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | attack spinning top, beyblade pegasus |
| `IronShell` | Iron Shell | defense beyblade, heavy spinning top |
| `VoltDash` | Volt Dash | stamina spinning top, flat beyblade |
| `ShadowBite` | Shadow Bite | dark spinning top, balance beyblade |
| `FrostCrown` | Frost Crown | ice spinning top, crystal beyblade |
| `EmberCore` | Ember Core | fire spinning top, flame beyblade |

## How to import

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search using the hints above (or import your own FBX/GLB)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
5. Set `PrimaryPart` on the collision part; name it `Hull` if possible
6. Play — `BeyModelBuilder` clones the model instead of procedural layers

**Alternative:** paste a MeshId into `BeyCatalog.modelAssets.meshId` for a single MeshPart.

See `docs/BEY-MODELS.md` for full setup.
