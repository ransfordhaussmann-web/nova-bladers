# Bey Models — Studio Import

Procedural 3D models are built at runtime. Optional Creator Store / custom models can replace them.

## Studio import (Creator Store or Blender)

| Folder name | Bey | Notes |
|-------------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `CrimsonVortex` | Crimson Vortex | Creator Store spinning top, flat on ground |
| `GlacierMantle` | Glacier Mantle | Creator Store ice/defense top |

After import in Studio:

1. Place under `ReplicatedStorage → NovaBladers → Models → <FolderName>`
2. Set `PrimaryPart`, name collision part `Hull`
3. Scale ~3.5 studs wide, flat orientation
4. `BeyCatalog.modelRef.studioModelName` must match folder name

If no Studio model exists, `BeyModelBuilder` uses procedural layers automatically.
