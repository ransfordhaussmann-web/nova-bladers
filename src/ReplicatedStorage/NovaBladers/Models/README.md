# Bey Models (Creator Store / Studio Import)

Place imported Creator Store or Blender models here as **Model** instances.
`BeyModelBuilder` clones them when `modelRef.studioModelName` matches the folder child name.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostCrown | Frost Crown |

## Priority

1. `Models/<studioModelName>` — cloned and scaled to arena size
2. `BeyCatalog.modelAssets.meshId` — single MeshPart from Toolbox
3. Procedural layered build (fallback)

## Import steps

1. Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into `ReplicatedStorage/NovaBladers/Models`
3. Rename to the `studioModelName` from the table above
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead

See `docs/BEY-MODELS.md` for full setup.
