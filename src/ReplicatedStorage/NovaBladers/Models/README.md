
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store / Studio imports

| Model folder | Bey |
|--------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonFang` | Crimson Fang |
| `AuroraCrest` | Aurora Crest |

Place imported models under `ReplicatedStorage/NovaBladers/Models/`.
Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Optional: set `modelAssets.meshId` for Creator Store mesh IDs.
