# Bey Model Imports

Place Creator Store / Sketchfab imports here as **Model** instances.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` matches.

| Model name | Bey | Notes |
|------------|-----|-------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | Iron Shell | Optional Creator Store mesh |
| VoltDash | Volt Dash | Optional Creator Store mesh |
| ShadowBite | Shadow Bite | Optional Creator Store mesh |
| CrimsonFang | Crimson Fang | Optional Creator Store mesh |
| GlacierCore | Glacier Core | Optional Creator Store mesh |

After Studio import: `ReplicatedStorage → NovaBladers → Models → [Name]`

Procedural fallback builds run automatically when no model is present.
