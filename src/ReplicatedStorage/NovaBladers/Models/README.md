
Import Creator Store / Sketchfab models here for in-game use.

## Studio-Pfad

`ReplicatedStorage → NovaBladers → Models`

## Modelle

| Model-Name | Bey | Quelle |
|------------|-----|--------|
| NovaStriker | Nova Striker | Sketchfab (siehe docs/SKETCHFAB-NOVA-STRIKER.md) |
| CrimsonForge | Crimson Forge | Creator Store → "spinning top" / FBX-Import |
| FrostPrism | Frost Prism | Creator Store → "spinning top" / FBX-Import |

## Creator Store importieren

1. Roblox Studio → Toolbox → Creator Store → nach "spinning top" suchen
2. Modell in die Arena ziehen, skalieren (~3.5 Stud Durchmesser)
3. Als Kind von `Models` speichern (Name exakt wie `studioModelName` in BeyCatalog)
4. Optional: `meshId` in `BeyCatalog.modelAssets` eintragen für MeshPart-Fallback

Prozedurale Fallback-Modelle werden automatisch genutzt, wenn kein Studio-Modell vorhanden ist.
