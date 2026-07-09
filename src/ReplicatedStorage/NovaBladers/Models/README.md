# Bey Model Imports

Place imported Creator Store or FBX models here as **Model** instances.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonEdge` | Crimson Edge |
| `FrostHalo` | Frost Halo |

## Creator Store workflow

1. Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move under `ReplicatedStorage → NovaBladers → Models → <BeyId>`
4. Name matches `modelRef.studioModelName` in `BeyCatalog.lua`

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` (no folder import needed).

Without import, procedural builders in `BeyModelBuilder.lua` are used automatically.
