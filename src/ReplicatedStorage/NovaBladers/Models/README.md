# Bey Studio Models

Place imported Creator Store / Sketchfab models here as **Model** instances.
`BeyModelBuilder` clones by `modelRef.studioModelName` from `BeyCatalog.lua`.

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostCrown | Frost Crown |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Optional: set `PrimaryPart` or name collision part `Hull`
5. Play — imported mesh replaces procedural layers; spin ring stays

Without a Studio model, procedural fallback from `BeyModelBuilder.lua` is used.

Optional per-bey `modelAssets.meshId` in `BeyCatalog.lua` for direct Toolbox meshes.

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md`.
