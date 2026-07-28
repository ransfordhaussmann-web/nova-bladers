
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store imports (optional)

Place imported models here with these names:

| Model folder | Bey |
|--------------|-----|
| `NovaStriker` | Nova Striker |
| `CrimsonFang` | Crimson Fang |
| `AuroraCrest` | Aurora Crest |

Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name.
Procedural layers are used as fallback when no model is present.
