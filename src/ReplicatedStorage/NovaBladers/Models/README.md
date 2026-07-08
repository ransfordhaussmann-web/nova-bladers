
Optional Creator Store / Sketchfab models for in-game Beys.

## Studio import

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Studio model name | Bey |
|---|---|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| BlazeOrbit | Blaze Orbit |
| TitanGuard | Titan Guard |

`BeyModelBuilder` auto-clones a matching model when present; otherwise procedural geometry is used.

## Creator Store

1. Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model, copy MeshId
3. In `BeyCatalog.lua` add `modelAssets = { meshId = "rbxassetid://..." }`
