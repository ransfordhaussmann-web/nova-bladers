# Nach dem Download — Nova Striker

## Automatisch (empfohlen)

Doppelklick auf **`import-nova-striker.bat`** im Projektroot.

## Sketchfab — du bist eingeloggt

Modell (exklusive Version):  
https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e

**Am einfachsten:** Auf der Seite **Download 3D Model → GLB** → speichern in:

```
beyblade model/storm-pegasus.glb
```

Dann `import-nova-striker.bat` — fertig.

**Oder API-Token:** `tools/nova-striker-import/.env` mit `SKETCHFAB_API_TOKEN=...` (siehe `.env.example`).

## Falls du die Sketchfab-GLB hast

Lege sie hier ab (beliebiger Dateiname):

```
beyblade model/storm-pegasus.glb
```

Dann nochmal `import-nova-striker.bat` — fertig.

## Roblox Studio (optional)

1. `start-rojo.bat`
2. **File → Import 3D** → `assets/models/NovaStriker.glb`
3. Command Bar → `setup-in-studio.lua` einfügen
4. Play → Nova Striker

Ohne Studio-Import: Das verbesserte Pegasus-Modell ist **sofort im Spiel** sichtbar.
