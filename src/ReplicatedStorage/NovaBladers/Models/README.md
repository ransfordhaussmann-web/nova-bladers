# Bey Models — Studio Import

Place Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model name | Bey |
|------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostCrown | Frost Crown |

## Import steps

1. Roblox Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model, scale to ~3.5 studs wide, lay flat on arena
3. Rename to the table name above
4. Move to `ReplicatedStorage → NovaBladers → Models`
5. Play — `BeyModelBuilder` clones the model; procedural fallback if missing

See `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker details.
