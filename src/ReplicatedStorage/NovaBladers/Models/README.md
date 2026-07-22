
Import Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| FrostCrown | Frost Crown |
| EmberCore | Ember Core |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<studioModelName>`

Loading priority (BeyModelBuilder):
1. Clone from this Models/ folder (`modelRef.studioModelName`)
2. `modelAssets.meshId` in BeyCatalog
3. Procedural 3D fallback
