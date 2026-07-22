
Import Creator Store / Sketchfab models here for in-game use.

| Model folder | Bey |
|--------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostCoil | Frost Coil |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

`BeyModelBuilder` loads from this folder first (`modelRef.studioModelName`), then falls back to `modelAssets.meshId`, then procedural layers.

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md`.
