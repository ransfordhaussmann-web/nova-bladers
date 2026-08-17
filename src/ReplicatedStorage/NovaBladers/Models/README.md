# Bey Models (optional Studio imports)

Procedural 3D models are built at runtime. To use a Creator Store or imported mesh instead:

1. Insert model in Roblox Studio under `ReplicatedStorage → NovaBladers → Models`
2. Name it exactly as `studioModelName` in `BeyCatalog.lua`:

| Bey | Folder name |
|-----|-------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Blaze Wheel | `BlazeWheel` |
| Frost Veil | `FrostVeil` |

3. Set `PrimaryPart` (or a part named `Hull`) and keep scale ~3–4 studs wide.

See `docs/BEY-MODELS.md` for Toolbox search tips and `modelAssets.meshId` fallback.
