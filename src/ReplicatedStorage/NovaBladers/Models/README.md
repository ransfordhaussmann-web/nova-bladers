# Bey 3D Models (Creator Store / Studio Import)

Import spinning-top models from Roblox Creator Store or Sketchfab into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

## Model names

| Bey | studioModelName | Fallback |
|-----|-----------------|----------|
| Nova Striker | `NovaStriker` | Procedural + Sketchfab ref |
| Iron Shell | `IronShell` | Procedural |
| Volt Dash | `VoltDash` | Procedural |
| Shadow Bite | `ShadowBite` | Procedural |
| Crimson Fang | `CrimsonFang` | Procedural |
| Frost Halo | `FrostHalo` | Procedural |

## Import priority (`BeyModelBuilder`)

1. **Models/** folder clone (`modelRef.studioModelName`)
2. **Creator Store** mesh (`modelAssets.meshId` in `BeyCatalog.lua`)
3. **Procedural** builder (always available)

## Creator Store meshId

Search Toolbox → Creator Store → "spinning top", then paste the asset id into `BeyCatalog`:

```lua
modelAssets = { meshId = "rbxassetid://123456789", size = Vector3.new(3.6, 1.2, 3.6) },
```

Crimson Fang and Frost Halo have commented `modelAssets` slots ready for paste.
