# Studio Model Slots

Import Creator Store or custom 3D models here (one Model per bey id).

After Studio import: `ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| studioModelName | Bey | Toolbox hint |
|-----------------|-----|--------------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | spinning top / metal defense ring |
| `VoltDash` | Volt Dash | flat stamina ring / lightning top |
| `ShadowBite` | Shadow Bite | dark aura spinning top |
| `CrimsonEdge` | Crimson Edge | red attack blades / serrated top |
| `FrostHalo` | Frost Halo | ice crystal ring / frost shield top |

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a Studio folder model.

Procedural fallback builds run when no Studio model or meshId is present.
