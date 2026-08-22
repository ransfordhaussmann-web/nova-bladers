# Creator Store Model Hooks

Place imported Creator Store / Toolbox models here as **Model** instances.
The game clones them at runtime when `modelRef.studioModelName` matches.

| studioModelName | Bey |
|-----------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonVortex | Crimson Vortex |
| GlacierMantle | Glacier Mantle |

## Studio Setup

1. Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
3. Set `PrimaryPart` (or name collision part `Hull`)
4. Play — procedural fallback used if model missing

See `docs/BEY-MODELS.md` for meshId and Sketchfab import options.
