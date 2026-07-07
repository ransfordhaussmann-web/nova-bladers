# Bey Models — Creator Store / Studio Import

Import Creator Store or custom 3D models into Studio, then place them here.
Procedural fallback models are used when no import is present.

| Model folder | Bey | Type |
|--------------|-----|------|
| `NovaStriker` | Nova Striker | Attack |
| `IronShell` | Iron Shell | Defense |
| `VoltDash` | Volt Dash | Stamina |
| `ShadowBite` | Shadow Bite | Balance |
| `CrimsonForge` | Crimson Forge | Attack |
| `FrostTide` | Frost Tide | Balance |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** — search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` on the collision part (name it `Hull` if possible)
5. Play → pick the bey → imported mesh replaces procedural layers

Alternative: paste a **MeshId** into `BeyCatalog.lua` → `modelAssets.meshId`.

See `docs/BEY-MODELS.md` for full setup guide.
