# Bey Models — Import in Studio

Optional Creator Store / custom 3D models for each bey.

## Ordnerstruktur

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `FrostPrism` | Frost Prism |
| `BlazeRipper` | Blaze Ripper |

## Import

1. Roblox Studio → Toolbox → Creator Store → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, weld parts, optional `Hull` collision part
5. Rojo sync or manual copy — `BeyModelBuilder` auto-clones when present

Without imported models, procedural 3D layers are built at runtime.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
