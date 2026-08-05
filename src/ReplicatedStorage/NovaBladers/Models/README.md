# Bey Models — Studio Import

Place Creator Store or custom 3D models here as **Models** matching `studioModelName` in `BeyCatalog.lua`.

| Model Name | Bey |
|------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| GlacierSpin | Glacier Spin |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search `spinning top` or `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move to `ReplicatedStorage → NovaBladers → Models → <ModelName>`
4. Set `PrimaryPart` or name collision part `Hull`
5. Play — `BeyModelBuilder` clones the model instead of procedural fallback

Without a Studio model, procedural 3D layers are used automatically.
