
Import optional Creator Store / Sketchfab models here for in-game use.

| Model folder | Bey |
|--------------|-----|
| **NovaStriker** | Nova Striker |
| **FrostFang** | Frost Fang |
| **BlazeCrown** | Blaze Crown |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `modelRef.studioModelName` in `BeyCatalog.lua` (already configured).
Alternatively paste a `meshId` into `modelAssets` on the bey entry.

See `docs/BEY-MODELS.md` for full setup steps.
