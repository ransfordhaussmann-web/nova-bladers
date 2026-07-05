# Bey Models (Creator Store / Studio Import)

Procedural fallbacks exist for all 6 Beys. Optional Studio models improve visuals.

## Model folder names

| Bey ID        | Studio model name | Notes                          |
|---------------|-------------------|--------------------------------|
| NovaStriker   | NovaStriker       | Sketchfab GLB (see docs)       |
| IronShell     | IronShell         | Creator Store spinning top     |
| VoltDash      | VoltDash          | Creator Store spinning top     |
| ShadowBite    | ShadowBite        | Creator Store spinning top     |
| CrimsonBlaze  | CrimsonBlaze      | Creator Store spinning top     |
| FrostOrbit    | FrostOrbit        | Creator Store spinning top     |

## Import in Roblox Studio

1. Toolbox → **Creator Store** → search "spinning top" / "beyblade-style"
2. Insert model under `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
3. Or set `modelAssets.meshId` in `BeyCatalog.lua` with the rbxassetid

After import: Rojo sync or copy into `src/ReplicatedStorage/NovaBladers/Models/` if using file-based models.
