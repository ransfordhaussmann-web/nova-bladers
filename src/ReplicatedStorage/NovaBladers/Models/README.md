
Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

Optional Creator Store models (place under Models/):
- **IronShell** — defense bey
- **CrimsonFang** — attack bey
- **FrostCore** — defense bey

Set `modelRef.studioModelName` in BeyCatalog to match the folder name.
Procedural fallbacks are used when no model is present.
