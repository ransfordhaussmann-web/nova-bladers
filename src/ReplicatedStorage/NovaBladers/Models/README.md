# Bey Models (Studio Import)

Place imported Creator Store or Sketchfab models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Studio folder name | Bey |
|--------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostOrbit | Frost Orbit |

## Import steps

1. Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage → NovaBladers → Models → <Name>`
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of folder clone

Procedural 3D layers are used when no Studio model or meshId is present.

See `docs/BEY-MODELS.md` for full setup.
