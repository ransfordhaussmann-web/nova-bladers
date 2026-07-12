# Bey Models (Studio Import)

Place Creator Store or imported 3D models here. The game clones them automatically when `modelRef.studioModelName` matches the folder name in `BeyCatalog.lua`.

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonForge` | Crimson Forge |
| `FrostPrism` | Frost Prism |

## Setup

1. Studio → **View → Toolbox → Creator Store** → search `spinning top`
2. Insert model, scale to ~3.5 studs wide, flat on ground
3. Rename to the table name above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Set **PrimaryPart** (or child named `Hull`)

Without a Studio model, procedural layers are built at runtime.

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker only).
