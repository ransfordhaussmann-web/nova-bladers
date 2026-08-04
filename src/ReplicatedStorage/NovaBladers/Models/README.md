# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as child **Models** of this folder.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrimsonVortex` | Crimson Vortex | Creator Store spin top → flat on arena |
| `FrostCrown` | Frost Crown | Creator Store spin top → flat on arena |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set **PrimaryPart** (or child `Hull`). The game auto-clones when present; otherwise procedural 3D layers are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a full model.
