# Nova Bladers — Studio Model Imports

Place imported Creator Store / Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| Model Name | Bey | Notes |
|------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | Iron Shell | Creator Store spinning top |
| VoltDash | Volt Dash | Creator Store spinning top |
| ShadowBite | Shadow Bite | Creator Store spinning top |
| CrimsonForge | Crimson Forge | Creator Store spinning top |
| FrostPrism | Frost Prism | Creator Store spinning top |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set `PrimaryPart` on collision hull, name it `Hull` if possible
5. Play — procedural fallback used until model exists in folder

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for single-mesh imports.
