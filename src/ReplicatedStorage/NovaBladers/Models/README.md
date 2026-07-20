# Bey 3D Models (Creator Store / Studio Import)

`BeyModelBuilder` lädt Modelle in dieser Priorität:

1. **Models/**-Ordner — `modelRef.studioModelName` in `BeyCatalog.lua`
2. **Creator Store** — `modelAssets.meshId` in `BeyCatalog.lua`
3. **Procedural** — eingebaute Builder in `BeyModelBuilder.lua`

## Studio-Import (empfohlen)

Roblox Studio → Toolbox → Creator Store → „spinning top" suchen → Modell in diesen Ordner ziehen.

| Modellname (in Models/) | Bey |
|-------------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonFang | Crimson Fang |
| FrostCrown | Frost Crown |
| SolarFlare | Solar Flare |

Nach dem Import: `ReplicatedStorage → NovaBladers → Models → <Name>`

## Alternativ: meshId

In `BeyCatalog.lua` den `modelAssets`-Block auskommentieren und `rbxassetid://…` eintragen.
