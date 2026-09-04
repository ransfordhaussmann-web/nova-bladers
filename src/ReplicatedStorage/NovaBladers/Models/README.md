# Bey Studio Models (optional)

Import Creator Store or custom 3D models into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName | Fallback |
|-----|-----------------|----------|
| Nova Striker | NovaStriker | Procedural layers |
| Iron Shell | IronShell | Procedural layers |
| Volt Dash | VoltDash | Procedural layers |
| Shadow Bite | ShadowBite | Procedural layers |
| Crimson Fang | CrimsonFang | Procedural layers |
| Frost Crown | FrostCrown | Procedural layers |

When a matching model exists, `BeyModelBuilder` clones and scales it (`modelRef.targetSize`, default 3.5 studs).
Otherwise procedural 3D layers are built at runtime.

See `docs/BEY-MODELS.md` for import steps.
