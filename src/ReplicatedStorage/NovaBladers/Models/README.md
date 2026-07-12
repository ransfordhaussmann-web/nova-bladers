# Bey 3D-Modelle (Creator Store / Studio Import)

Procedural Fallback läuft automatisch. Für Creator-Store- oder Sketchfab-Modelle:

1. Modell in Studio importieren (Toolbox → Creator Store oder GLB-Import)
2. Unter `ReplicatedStorage → NovaBladers → Models` ablegen
3. Name muss `studioModelName` aus `BeyCatalog.modelRef` entsprechen

| Bey | studioModelName | Typ |
|-----|-----------------|-----|
| Nova Striker | NovaStriker | Attack |
| Iron Shell | IronShell | Defense |
| Volt Dash | VoltDash | Stamina |
| Shadow Bite | ShadowBite | Balance |
| Crimson Forge | CrimsonForge | Attack |
| Frost Prism | FrostPrism | Defense |

Nova Striker: siehe auch `docs/SKETCHFAB-NOVA-STRIKER.md`

Ohne importiertes Modell wird der prozedurale Builder aus `BeyModelBuilder.lua` verwendet.
