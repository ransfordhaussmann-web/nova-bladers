# Nach dem Download — Nova Striker

## Automatisch (empfohlen)

Doppelklick auf **`import-nova-striker.bat`** im Projektroot.

Das Skript macht alles selbst:
- Sucht deine GLB in `beyblade model/` (falls vorhanden)
- Baut sonst automatisch ein Pegasus-Modell
- Erzeugt `NovaStriker.glb` in `tools/nova-striker-import/output/` und `assets/models/`

**Du musst nichts manuell kopieren.**

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
