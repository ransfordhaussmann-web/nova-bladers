# Bey 3D Models (Creator Store / Studio Import)

Import spinning-top meshes from Roblox Studio **Toolbox → Creator Store** into this folder.
Each model name must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Studio Model Name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostHalo | Frost Halo |

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Procedural fallbacks in `BeyModelBuilder.lua` are used when no Studio model is present.
Optional: set `modelAssets.meshId` in the catalog for a direct rbxassetid mesh.
