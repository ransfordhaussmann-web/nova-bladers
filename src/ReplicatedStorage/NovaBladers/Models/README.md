# Bey Studio Models

Import Creator Store or custom 3D models here for in-game use.

## Expected model names

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonBlaze` | Crimson Blaze |
| `FrostOrbit` | Frost Orbit |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `PrimaryPart` (or name collision part `Hull`). Procedural layers are used as fallback when no model folder exists.

Optional: paste Creator Store `meshId` into `BeyCatalog.lua` → `modelAssets.meshId`.

See `docs/BEY-MODELS.md` for full setup steps.
