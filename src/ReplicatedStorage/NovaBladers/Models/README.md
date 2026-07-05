# Bey 3D Models (Studio Import)

Optional Creator Store / Sketchfab models for in-game Bey visuals.

## Import paths

After Studio import, place models under:

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Bey | Model folder | Notes |
|-----|--------------|-------|
| Nova Striker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| Crimson Fang | `CrimsonFang` | Creator Store spinning top → import as Model |
| Frost Halo | `FrostHalo` | Creator Store spinning top → import as Model |

## Creator Store workflow

1. Roblox Studio → Toolbox → **Creator Store** → search "spinning top"
2. Insert model into `Models/<ModelName>`
3. Optional: copy mesh `rbxassetid` into `BeyCatalog.modelAssets.meshId` for `MeshPart` fallback

Procedural builders in `BeyModelBuilder.lua` are used when no Studio model is present.
