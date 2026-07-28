# Bey Studio Models

Import Creator Store / Sketchfab models here for in-game use.

| Model Name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `CrimsonFang` | Crimson Fang | Optional Creator Store import |
| `FrostCrown` | Frost Crown | Optional Creator Store import |

After Studio import: **ReplicatedStorage → NovaBladers → Models → &lt;ModelName&gt;**

Procedural fallback models are used automatically when no Studio model is present.
To use a Creator Store mesh without a full model, set `modelAssets.meshId` in `BeyCatalog.lua`.
