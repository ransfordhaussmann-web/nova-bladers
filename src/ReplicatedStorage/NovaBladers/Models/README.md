
Import Creator Store / Sketchfab models here for in-game use.

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

The game auto-clones from this folder when `modelRef.studioModelName` is set in `BeyCatalog.lua`.
Falls back to procedural 3D layers if no model is found.
