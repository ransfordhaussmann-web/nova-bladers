# Bey Models (Studio Import)

Place imported Creator Store or custom 3D models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `CrimsonSpike` | Crimson Spike | Creator Store spinning top |
| `FrostCoil` | Frost Coil | Creator Store spinning top |

## Studio path

`ReplicatedStorage` → `NovaBladers` → `Models` → `<ModelName>`

## Creator Store workflow

1. Toolbox → Creator Store → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide
3. Move under `Models/` with the name from the table above
4. Optional: copy MeshId into `BeyCatalog.modelAssets.meshId` instead

Procedural layered models are used automatically when no Studio model is present.
