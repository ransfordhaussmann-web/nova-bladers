# Bey Models — Studio Import

Import Creator Store or custom 3D models into Roblox Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

Procedural fallback models are built automatically when no Studio model is found.

## studioModelName per Bey

| Bey | studioModelName | Type |
|-----|-----------------|------|
| Nova Striker | NovaStriker | Attack |
| Iron Shell | IronShell | Defense |
| Volt Dash | VoltDash | Stamina |
| Shadow Bite | ShadowBite | Balance |
| Crimson Fang | CrimsonFang | Attack |
| Granite Fort | GraniteFort | Defense |
| Solar Drift | SolarDrift | Stamina |
| Phantom Edge | PhantomEdge | Balance |
| Crystal Edge | CrystalEdge | Attack |
| Blaze Crown | BlazeCrown | Balance |

## Import steps

1. Open Roblox Studio → Toolbox → Creator Store
2. Search `spinning top` or import FBX via File → Import 3D
3. Place model under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Name the model exactly as in the table above
5. Set `PrimaryPart` or name collision part `Hull`
6. Rojo sync → Play to test

See also `docs/BEY-MODELS.md` for meshId and procedural layer details.
