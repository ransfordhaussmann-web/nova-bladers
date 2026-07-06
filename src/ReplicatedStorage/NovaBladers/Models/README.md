# Bey 3D Models (Creator Store / Studio Import)

Place imported models here as **Model** instances. `BeyModelBuilder` clones them when `modelRef.studioModelName` matches.

| Studio folder name | Bey |
|--------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostOrbit | Frost Orbit |

## Import options

1. **Studio Models folder** — Import GLB/mesh under `ReplicatedStorage → NovaBladers → Models → <Name>`
2. **Creator Store meshId** — Set `modelAssets.meshId` in `BeyCatalog.lua` (Toolbox → Creator Store → spinning top)

If no model is found, procedural geometry is used automatically.
