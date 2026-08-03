# Bey Models — Studio Import Folder

Place imported 3D models here (Rojo syncs to `ReplicatedStorage.NovaBladers.Models`).

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | Creator Store or custom import |
| `VoltDash` | Volt Dash | Creator Store or custom import |
| `ShadowBite` | Shadow Bite | Creator Store or custom import |
| `CrimsonFang` | Crimson Fang | Creator Store or custom import |
| `NeonPulse` | Neon Pulse | Creator Store or custom import |

## Quick setup

1. Toolbox → Creator Store → search `spinning top` or `bey blade`
2. Insert model, scale to ~3–4 studs wide, lay flat
3. Rename to the table name above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of full model import

If no model is present, procedural layers are built at runtime.
