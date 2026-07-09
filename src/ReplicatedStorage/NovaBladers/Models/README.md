
Import optional Creator Store / custom 3D models here for in-game use.

| Model folder | Bey | Creator Store hint |
|--------------|-----|-------------------|
| `NovaStriker` | Nova Striker | spinning top / attack |
| `CrimsonEdge` | Crimson Edge | spinning top / attack blade |
| `FrostHalo` | Frost Halo | spinning top / ice ring |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Without import, procedural models are built automatically by `BeyModelBuilder.lua`.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a full model.
