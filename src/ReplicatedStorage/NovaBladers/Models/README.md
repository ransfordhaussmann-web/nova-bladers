# Bey Models (Studio Import)

Place imported Creator Store or custom 3D models here as **Model** instances.
`BeyModelBuilder` clones them when `modelRef.studioModelName` matches the folder name.

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `BlazeVortex` | Blaze Vortex |
| `FrostCrown` | Frost Crown |

## Creator Store workflow

1. Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <BeyId>`
4. Optional: set `PrimaryPart` or name collision part `Hull`
5. Or paste mesh **rbxassetid** into `BeyCatalog.modelAssets.meshId` instead

See `docs/BEY-MODELS.md` for full setup.
