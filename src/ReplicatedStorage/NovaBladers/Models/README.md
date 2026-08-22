# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances.
The game clones them at runtime when `modelRef.studioModelName` matches the folder name.

## Expected structure

```
ReplicatedStorage/NovaBladers/Models/
├── NovaStriker      (Model)
├── IronShell        (Model)
├── VoltDash         (Model)
├── ShadowBite       (Model)
├── CrimsonVortex    (Model)
└── GlacierMantle    (Model)
```

## How to import

1. Roblox Studio → Toolbox → Creator Store → search "spinning top" / "bey blade"
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`

If no Studio model exists, `BeyModelBuilder` falls back to procedural 3D layers.

See also: `docs/BEY-MODELS.md`
