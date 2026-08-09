# Bey Model Imports

Place imported Creator Store or Sketchfab models here as **Model** instances.

| Folder name     | Bey           | Creator Store search hint        |
|-----------------|---------------|----------------------------------|
| `NovaStriker`   | Nova Striker  | spinning top blue attack         |
| `CrimsonFang`   | Crimson Fang  | spinning top fire red            |
| `GlacierMantle` | Glacier Mantle| spinning top ice crystal         |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <FolderName>`

Set `PrimaryPart` (or name collision part `Hull`). Procedural layers are skipped when a model clone succeeds.

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`).

See also `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import workflow.
