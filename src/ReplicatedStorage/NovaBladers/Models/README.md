# Nova Bladers — Imported 3D Models

Place Creator Store or imported GLB models here (Rojo syncs to `ReplicatedStorage.NovaBladers.Models`).

| Folder name | Bey | Creator Store search hints |
|-------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | spinning top attack, metal fusion top |
| `IronShell` | Iron Shell | spinning top defense, heavy metal top |
| `VoltDash` | Volt Dash | spinning top stamina, flat ring top |
| `ShadowBite` | Shadow Bite | spinning top dark, purple top |
| `EmberCore` | Ember Core | spinning top fire, red attack top |
| `TidalRing` | Tidal Ring | spinning top water, blue ring top |

## After Studio import

1. Scale to ~3.5 stud diameter, lay flat on ground
2. Set `PrimaryPart` or name hull part `Hull`
3. Weld child parts to PrimaryPart
4. Name folder exactly as in table above

Alternative: paste MeshId in `CreatorStoreConfig.lua` (no folder needed).

See `docs/BEY-MODELS.md` for full workflow.
