# Bey Models (Creator Store / Studio Import)

Import Creator Store or custom spinning-top models into this folder as **Model** instances.

## Supported model names

| Studio Model Name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostCrown | Frost Crown |
| SolarFlare | Solar Flare |

## How to import

1. Roblox Studio → Toolbox → **Creator Store** → search "spinning top"
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to the `studioModelName` from `BeyCatalog.lua`
4. Set a **PrimaryPart** (or child named `Hull`) for welding

If no Studio model exists, `BeyModelBuilder` falls back to procedural 3D parts.

## Optional: meshId shortcut

Set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart without a full Model import.
