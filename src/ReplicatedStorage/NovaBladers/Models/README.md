# Bey 3D Models (Creator Store / Sketchfab Import)

Import GLB/FBX models into Studio under `ReplicatedStorage → NovaBladers → Models`.

When a matching model exists, `BeyModelBuilder` clones it instead of the procedural mesh.

| Studio model name | Bey | Sketchfab reference |
|-------------------|-----|---------------------|
| `NovaStriker` | Nova Striker | [Storm Pegasus ref](https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660) — see `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | [Heavy Spinning Top](https://sketchfab.com/3d-models/day31-spinning-top-d090504b2d994d7c812c14bc963afe90) |
| `VoltDash` | Volt Dash | [Spinning Top Mid Poly](https://sketchfab.com/3d-models/spinning-top-mid-poly-7463f340bcfd461ea12a5edcf76f7463) |
| `ShadowBite` | Shadow Bite | [Spinning Top](https://sketchfab.com/3d-models/spinning-top-e91f8742370a420e9102dc13e9eb29c9) |
| `ApexDrill` | Apex Drill | Same as Shadow Bite (recolor in Studio) or any attack-style top |
| `NeonTide` | Neon Tide | Same as Volt Dash (recolor in Studio) or any flat-ring top |

## Import steps

1. Download GLB from Sketchfab **or** insert a mesh from **Toolbox → Creator Store**
2. **File → Import 3D** in Studio
3. Scale to ~3.5 studs wide, flat on arena floor
4. Rename to the **Studio model name** from the table above
5. Move to `ReplicatedStorage/NovaBladers/Models/<Name>`
6. Set `PrimaryPart` (or child part named `Hull`)

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a Creator Store MeshPart without a full model folder.
