# Bey Studio Models

Optional 3D imports for Creator Store / Sketchfab meshes. Procedural fallbacks work without any imports.

| Model name | Bey | Source |
|------------|-----|--------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `FrostCrown` | Frost Crown | Studio import or Toolbox mesh |

## Creator Store (Toolbox)

1. Roblox Studio → Toolbox → Creator Store → search spinning top / arena bey
2. Copy the asset id into `BeyCatalog.lua` → `modelAssets.meshId` for the matching Bey
3. Supported slots: `IronShell`, `CrimsonFang`, `FrostCrown` (`meshId = nil` = procedural model)

After Studio import: **ReplicatedStorage → NovaBladers → Models → &lt;ModelName&gt;**
