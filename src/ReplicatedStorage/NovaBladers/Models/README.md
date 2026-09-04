# Creator Store Bey Models

Import Creator Store spinning-top models into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

`BeyModelBuilder` clones these models at runtime when present; otherwise it falls back to procedural meshes.

## Import table

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

## Studio import steps

1. Open Roblox Studio → Toolbox → Creator Store
2. Search for spinning-top / arena-style models (original IP only — no trademarked names)
3. Insert model into `ReplicatedStorage.NovaBladers.Models`
4. Rename to the `studioModelName` from the table above
5. Set a `PrimaryPart` on the model (or ensure a `Hull` part exists)
6. Play-test — `BeyModelBuilder` auto-scales to ~3.5 stud diameter

## Optional: external meshId

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from the Creator Store.
