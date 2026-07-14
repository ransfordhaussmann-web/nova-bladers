
Import optional Creator Store / custom 3D models here for in-game use.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `EmberCore` | Ember Core |
| `CrystalGuard` | Crystal Guard |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <Name>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Optional: set `modelAssets.meshId` for direct Toolbox mesh IDs (see docs/BEY-MODELS.md).
