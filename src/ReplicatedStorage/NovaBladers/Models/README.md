
Import Creator Store or custom 3D models here for in-game use.

## Model folders (one per Bey)

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonBlaze` | Crimson Blaze |
| `FrostCrown` | Frost Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <FolderName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` (already configured for all 6).

Alternatively, set `modelAssets.meshId` in the catalog for Toolbox mesh IDs.

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker Sketchfab import.
