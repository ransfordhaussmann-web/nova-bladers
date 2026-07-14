# Bey Models — Creator Store Import

Place imported 3D models here as **Model** instances. The game clones them at runtime when present; otherwise procedural layers are used.

| Studio model name | Bey | Creator Store search terms |
|-------------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | spinning top, attack blade, blue energy ring |
| `IronShell` | Iron Shell | spinning top, heavy shell, defense ring |
| `VoltDash` | Volt Dash | spinning top, flat ring, lightning |
| `ShadowBite` | Shadow Bite | spinning top, dark aura, fang blade |
| `CrimsonEdge` | Crimson Edge | spinning top, fire blade, red attack |
| `FrostHalo` | Frost Halo | spinning top, ice crystal, frost ring |

## Import steps (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search using the terms above (or `spinning top`, `bey blade metal`)
3. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
4. Rename to the **Studio model name** from the table
5. Move to `ReplicatedStorage → NovaBladers → Models`
6. Set **PrimaryPart** (or name collision part `Hull`)
7. Play — `BeyModelBuilder` auto-clones and welds to physics hull

See `docs/BEY-MODELS.md` for meshId fallback via `modelAssets` in `BeyCatalog.lua`.
