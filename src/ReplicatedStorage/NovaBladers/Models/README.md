# Creator Store Model Slots

Import spinning-top models from Roblox Studio Toolbox → Creator Store into these folders.
After import, place each model under `ReplicatedStorage/NovaBladers/Models/` with the exact name below.

| Folder | Bey | Notes |
|--------|-----|-------|
| `NovaStriker` | Nova Striker | Sketchfab GLB import — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Optional Creator Store mesh |
| `VoltDash` | Volt Dash | Optional Creator Store mesh |
| `ShadowBite` | Shadow Bite | Optional Creator Store mesh |
| `FrostPrism` | Frost Prism | Optional Creator Store mesh |
| `BlazeRipper` | Blaze Ripper | Optional Creator Store mesh |

`BeyModelBuilder` clones a matching folder model when present; otherwise it builds procedural 3D layers.
Set `PrimaryPart` on imported models and name the collision part `Hull` for best results.
