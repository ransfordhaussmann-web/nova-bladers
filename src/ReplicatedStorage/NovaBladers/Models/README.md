# Bey Models (Studio Import)

Place imported Creator Store / Sketchfab models here as **Model** instances named after `studioModelName` in `BeyCatalog.lua`.

| Model name   | Bey          | Notes |
|--------------|--------------|-------|
| NovaStriker  | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| IronShell    | Iron Shell   | Toolbox → "spinning top" / "metal defense" |
| VoltDash     | Volt Dash    | Toolbox → "spinning top" / stamina style |
| ShadowBite   | Shadow Bite  | Toolbox → "spinning top" / dark balance |
| CrimsonFang  | Crimson Fang | Toolbox → "spinning top" / attack blade |
| FrostHalo    | Frost Halo   | Toolbox → "spinning top" / ice defense |

After import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

Set `PrimaryPart` (or name collision part `Hull`). `BeyModelBuilder` scales to `targetSize`, lays flat via `importRotation`, and welds to the physics hull.

Without a Studio model, procedural 3D layers are built at runtime. Optional `modelAssets.meshId` in the catalog overrides procedural meshes when set.
