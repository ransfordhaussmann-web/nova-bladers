
Import Creator Store / Sketchfab models here for in-game use.

Place each model under `ReplicatedStorage/NovaBladers/Models/` with the matching name:

| Model name | Bey |
|------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonForge | Crimson Forge |
| FrostPrism | Frost Prism |

After Studio import: set `PrimaryPart`, weld parts, optional `Hull` on collision part.
`BeyModelBuilder` clones from this folder when `modelRef.studioModelName` is set; otherwise procedural layers are used.

See docs/BEY-MODELS.md for Creator Store search tips.
