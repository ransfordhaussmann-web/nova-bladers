# Bey Models — Studio Import

Place imported Creator Store / FBX models here. Rojo syncs this folder to `ReplicatedStorage.NovaBladers.Models`.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store spinning top |
| `VoltDash` | Volt Dash | Creator Store spinning top |
| `ShadowBite` | Shadow Bite | Creator Store spinning top |
| `CrimsonBlaze` | Crimson Blaze | Creator Store spinning top |
| `FrostCrown` | Frost Crown | Creator Store spinning top |

## How to import

1. Studio → **Toolbox → Creator Store** → search `spinning top`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Rename to the **Model name** above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Play — `BeyModelBuilder` clones the mesh instead of procedural layers

Procedural fallback models are used when no Studio model is present.
