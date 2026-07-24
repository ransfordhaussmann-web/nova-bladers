# Creator Store / Studio Models

Place imported Creator Store or Blender models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| Model name | Bey |
|------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostCrown | Frost Crown |

## How to import

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` or name collision part `Hull`
5. Play — procedural fallback is used if model is missing

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a Studio model.
