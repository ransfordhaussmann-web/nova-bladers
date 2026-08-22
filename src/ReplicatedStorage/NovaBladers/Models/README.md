# Bey Model Imports

Place Creator Store or imported 3D models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| studioModelName | Bey | Creator Store search hint |
|-----------------|-----|---------------------------|
| NovaStriker | Nova Striker | `spinning top attack blue` |
| IronShell | Iron Shell | `spinning top defense metal` |
| VoltDash | Volt Dash | `spinning top yellow lightning` |
| ShadowBite | Shadow Bite | `spinning top dark purple` |
| CrimsonForge | Crimson Forge | `spinning top red metal forge` |
| FrostCrown | Frost Crown | `spinning top ice crystal` |

## Steps (Roblox Studio)

1. **View → Toolbox → Creator Store**
2. Search using the hint from `BeyCatalog.modelRef.creatorStoreQuery`
3. Insert model into `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set **PrimaryPart**, name collision part `Hull`, scale ~3–4 studs wide
5. Procedural fallback is used automatically if no model is present

## Sketchfab (Nova Striker only)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import steps.
