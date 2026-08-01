# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as **Model** instances.
The game auto-clones them when `modelRef.studioModelName` matches the folder child name.

| Studio model name | Bey | Notes |
|-------------------|-----|-------|
| `NovaStriker` | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| `IronShell` | Iron Shell | Defense shell — search "spinning top" in Creator Store |
| `VoltDash` | Volt Dash | Flat stamina ring style |
| `ShadowBite` | Shadow Bite | Dark / asymmetric fang style |
| `CrimsonFang` | Crimson Fang | Attack fang blades, red accent |
| `FrostRing` | Frost Ring | Ice / crystal ring style |

## Quick import

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model, scale to ~3.5 studs wide, lay flat on arena
3. Rename to the **Studio model name** from the table above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Play — procedural fallback is used if the model is missing

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (see docs/BEY-MODELS.md).
