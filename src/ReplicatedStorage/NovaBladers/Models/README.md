Import Sketchfab GLB here as **NovaStriker** for in-game use.
See docs/SKETCHFAB-NOVA-STRIKER.md

After Studio import: ReplicatedStorage → NovaBladers → Models → NovaStriker

## Creator Store slots (optional)

Import from Toolbox → Creator Store, then place under `Models/` or set `modelAssets.meshId` in `BeyCatalog.lua`:

| Bey | Studio model name | Search hint | Catalog field |
|-----|-------------------|-------------|---------------|
| Nova Striker | NovaStriker | spinning top attack | `modelRef.studioModelName` |
| Iron Shell | IronShell | spinning top defense | `modelRef.studioModelName` |
| Volt Dash | VoltDash | spinning top stamina | `modelRef.studioModelName` |
| Shadow Bite | ShadowBite | spinning top balance | `modelRef.studioModelName` |
| Crimson Blaze | CrimsonBlaze | spinning top fire | `modelAssets.meshId` |
| Frost Crown | FrostCrown | spinning top ice | `modelAssets.meshId` |

Procedural fallback builds are used when no imported model or meshId is configured.
