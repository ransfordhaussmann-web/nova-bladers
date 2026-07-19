# Bey 3D Models (Creator Store / Studio Import)

`BeyModelBuilder` lädt Modelle in dieser Priorität:

1. **Studio-Model** unter `Models/<studioModelName>` (aus `BeyCatalog.modelRef`)
2. **Creator Store Mesh** via `BeyCatalog.modelAssets.meshId`
3. **Procedural Fallback** (eingebaute Builder pro Bey-ID)

## Model-Namen (alle 6 Beys)

| Bey | Studio-Ordner |
|-----|---------------|
| Nova Striker | `NovaStriker` |
| Iron Shell | `IronShell` |
| Volt Dash | `VoltDash` |
| Shadow Bite | `ShadowBite` |
| Crimson Fang | `CrimsonFang` |
| Frost Crown | `FrostCrown` |

## Creator Store importieren

1. Roblox Studio → Toolbox → Creator Store → z. B. „spinning top“
2. Modell nach `ReplicatedStorage/NovaBladers/Models/<BeyId>` ziehen
3. Optional: `meshId` in `BeyCatalog.modelAssets` eintragen (für MeshPart-Fallback)

Nova Striker: siehe auch `docs/SKETCHFAB-NOVA-STRIKER.md` für Sketchfab-Import.
