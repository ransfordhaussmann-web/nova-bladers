# Bey Models — Studio Import

Place Creator Store or imported 3D models here as **Model** instances named after the Bey id.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonRipper` | Crimson Ripper |
| `FrostWard` | Frost Ward |

**Path in Studio:** `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Import steps

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` or `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/` and rename to the Bey id
4. Optional: set `PrimaryPart` or a part named `Hull` for welding

Without a Studio model, `BeyModelBuilder.lua` builds a procedural 3D Bey at runtime.

Optional per-Bey mesh without full model import — in `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker).
