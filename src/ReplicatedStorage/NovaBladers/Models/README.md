# Bey model import slots

Procedural models are built at runtime when no Studio model exists here.

## Nova Striker
Import Sketchfab GLB as **NovaStriker**. See `docs/SKETCHFAB-NOVA-STRIKER.md`.

After Studio import: `ReplicatedStorage → NovaBladers → Models → NovaStriker`

## Crimson Vortex
Import a Creator Store or custom mesh as **CrimsonVortex** (attack-type spinning top, ~3.5 studs wide).

## Glacier Shield
Import a Creator Store or custom mesh as **GlacierShield** (defense / ice-themed top, ~3.6 studs wide).

## Tips
- Set **PrimaryPart** or name collision part `Hull`
- Lay flat on arena floor; `importRotation` in `BeyCatalog` handles upright GLB imports
- Optional: `modelAssets.meshId` in catalog for single MeshPart without full model import
