# Nova Bladers — Imported 3D Models

Place Creator Store or imported GLB models here. `BeyModelBuilder` clones them when the folder name matches `modelRef.studioModelName` in `BeyCatalog.lua`.

| Model name | Bey | Notes |
|------------|-----|-------|
| `NovaStriker` | Nova Striker | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| `IronShell` | Iron Shell | Creator Store / custom import |
| `VoltDash` | Volt Dash | Creator Store / custom import |
| `ShadowBite` | Shadow Bite | Creator Store / custom import |
| `FrostCrown` | Frost Crown | Creator Store / custom import |
| `EmberClaw` | Ember Claw | Creator Store / custom import |

## Studio setup

1. Import mesh → scale to ~3.5 studs wide, flat on arena floor
2. Rename to the table name above
3. Move to `ReplicatedStorage → NovaBladers → Models`
4. Set **PrimaryPart** (or child part named `Hull`)

Procedural layers are used automatically when no model is present.

## Creator Store (MeshId only)

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` — see `docs/BEY-MODELS.md`.
