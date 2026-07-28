# Bey Model Slots — Creator Store / Studio Import

Place imported 3D models here as **Model** instances. `BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Model name | Bey | Creator Store search hints |
|------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | spinning top, attack bey |
| `IronShell` | Iron Shell | defense bey, heavy shell |
| `VoltDash` | Volt Dash | stamina ring, flat top |
| `ShadowBite` | Shadow Bite | dark balance bey |
| `CrimsonFang` | Crimson Fang | attack fang, red bey |
| `FrostHalo` | Frost Halo | ice crystal, defense ring |

## Studio path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store workflow

1. Toolbox → **Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `Models/<ModelName>`, set `PrimaryPart`, name collision part `Hull`
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of folder import

See `docs/BEY-MODELS.md` for meshId-only imports (no folder clone).
