# Nova Bladers — Creator Store Models

Optional 3D models from Roblox Creator Store. Procedural fallbacks work without imports.

## Studio placement

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

| Model | Bey | Notes |
|-------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB import (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell | Iron Shell | Toolbox: heavy defense top |
| VoltDash | Volt Dash | Toolbox: stamina / speed top |
| ShadowBite | Shadow Bite | Toolbox: balance / dark top |
| CrimsonForge | Crimson Forge | Toolbox: spinning top / forge hammer style |
| FrostPrism | Frost Prism | Toolbox: crystal / ice top style |

## Catalog wiring

- `modelRef.studioModelName` — clone from Models folder (auto-scale via `targetSize`)
- `modelAssets.meshId` — single MeshPart via `rbxassetid://` (skips procedural layers)

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "crystal" / "hammer".
