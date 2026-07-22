# Bey Model Imports

Place imported Creator Store / FBX models here as **Model** instances.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonEdge` | Crimson Edge | Creator Store spinning top → `ReplicatedStorage/NovaBladers/Models/CrimsonEdge` |
| `FrostHalo` | Frost Halo | Creator Store spinning top → `ReplicatedStorage/NovaBladers/Models/FrostHalo` |

After Studio import, `BeyModelBuilder` clones from this folder when present; otherwise procedural layers are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a full model.
