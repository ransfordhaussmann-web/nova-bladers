# Bey Models — Studio Import

Optional Creator-Store- oder eigene 3D-Modelle pro Bey. Ohne Import nutzt das Spiel die prozeduralen Layer aus `BeyModelBuilder.lua`.

## Ordnerstruktur in Studio

```
ReplicatedStorage
└── NovaBladers
    └── Models
        ├── NovaStriker
        ├── IronShell
        ├── VoltDash
        ├── ShadowBite
        ├── StarfallEdge
        ├── StoneHalo
        ├── ThunderCoil
        └── NightMaw
```

## Option A — Creator Store (MeshId)

1. Studio → **Toolbox → Creator Store** → z. B. „spinning top“
2. Modell einfügen, **MeshId** kopieren
3. In `BeyCatalog.lua` beim Bey `modelAssets.meshId` setzen:

```lua
modelAssets = {
    meshId = "rbxassetid://DEINE_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Option B — Eigenes Modell (FBX/GLB)

1. Modell in Blender o. ä. erstellen → **FBX** exportieren
2. Studio → **File → Import 3D**
3. Unter `ReplicatedStorage/NovaBladers/Models/<studioModelName>` ablegen
4. `PrimaryPart` setzen, Kollisions-Part `Hull` benennen
5. `modelRef.studioModelName` in `BeyCatalog.lua` muss zum Ordnernamen passen

## Priorität beim Spawn

1. Studio-Modell in `Models/` (wenn vorhanden)
2. Creator-Store `modelAssets.meshId`
3. Prozedurales 3D-Layer-Modell (Fallback)

## Skalierung

`modelRef.targetSize` steuert die Zielgröße in Studs (Standard: 3.5).
`modelRef.importRotation` korrigiert die Ausrichtung nach Import.
