
Import optional Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker (Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrystalVortex | Crystal Vortex — Creator Store: `spinning top crystal`, `ice bey` |
| EmberRing | Ember Ring — Creator Store: `spinning top fire`, `flame ring` |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`
Then set `modelAssets.meshId` in `BeyCatalog.lua` or rely on procedural fallback.
