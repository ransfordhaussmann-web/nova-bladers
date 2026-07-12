# Nova Bladers — Creator Store Models

Import spinning-top models from Roblox Studio **Toolbox → Creator Store** into this folder.

Each Bey in `BeyCatalog.lua` has a `modelRef.studioModelName`. After import, name the Model instance exactly as listed below.

| Model Name     | Bey            | Fallback        |
|----------------|----------------|-----------------|
| NovaStriker    | Nova Striker   | Procedural      |
| IronShell      | Iron Shell     | Procedural      |
| VoltDash       | Volt Dash      | Procedural      |
| ShadowBite     | Shadow Bite    | Procedural      |
| CrimsonForge   | Crimson Forge  | Procedural      |
| FrostPrism     | Frost Prism    | Procedural      |

**Studio path:** `ReplicatedStorage → NovaBladers → Models → <ModelName>`

If no Studio model is present, `BeyModelBuilder` uses procedural layered geometry automatically.

**Nova Striker (Sketchfab):** See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import.
