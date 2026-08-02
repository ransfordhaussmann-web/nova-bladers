
Import Creator Store / Sketchfab models here as **Model** instances for in-game use.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostRing | Frost Ring |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing locally.
Procedural fallback builds automatically when no Studio model is present.
