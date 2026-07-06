# Bey Models (Creator Store / Studio Import)

Place imported spinning-top models here as **Model** instances. Names must match `modelRef.studioModelName` in `BeyCatalog.lua`.

| Studio Model Name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostOrbit | Frost Orbit |

## Import options

1. **Studio Models folder** — Import GLB/mesh into `ReplicatedStorage → NovaBladers → Models → <Name>`
2. **Creator Store meshId** — Set `modelAssets.meshId` in `BeyCatalog.lua` (rbxassetid)

If no model is found, procedural builders in `BeyModelBuilder.lua` are used automatically.
