# Creator Store Bey Models

Import spinning-top meshes from Roblox Studio Toolbox → Creator Store into this folder.

| Studio model name | Bey | Search terms (Toolbox) |
|-------------------|-----|------------------------|
| NovaStriker | Nova Striker | spinning top, pegasus, attack bey |
| IronShell | Iron Shell | spinning top, defense bey, shield top |
| VoltDash | Volt Dash | spinning top, stamina bey, speed top |
| ShadowBite | Shadow Bite | spinning top, balance bey, dark top |
| CrimsonOrbit | Crimson Orbit | spinning top, fire bey, attack top |
| FrostAnchor | Frost Anchor | spinning top, ice bey, defense top |

After import: `ReplicatedStorage → NovaBladers → Models → <studioModelName>`

Procedural fallbacks render in-game when no Studio model is present.
Scale is adjusted via `modelRef.targetSize` in `BeyCatalog.lua` (default 3.5 studs).
