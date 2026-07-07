# Creator Store Bey Models

Import spinning-top meshes from Roblox Studio **Toolbox → Creator Store** into this folder.

## Model folders (one per Bey)

| Studio folder name | Bey | Search terms |
|--------------------|-----|--------------|
| NovaStriker | Nova Striker | spinning top, attack bey |
| IronShell | Iron Shell | spinning top, defense bey, metal shell |
| VoltDash | Volt Dash | spinning top, lightning, speed bey |
| ShadowBite | Shadow Bite | spinning top, dark, fang bey |
| CrimsonOrbit | Crimson Orbit | spinning top, fire, red bey, solar |
| FrostAnchor | Frost Anchor | spinning top, ice, frost, anchor bey |

## After import

Place each model under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

`BeyModelBuilder` clones imported models when present; otherwise procedural fallbacks are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct rbxassetid meshes.
