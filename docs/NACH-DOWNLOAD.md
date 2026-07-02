# Datei gefunden? — Nächste Schritte

Du hast die GLB im Ordner **`beyblade model`** — perfekt.

## Option A — Automatisch (empfohlen)

1. Stelle sicher, der Ordner heißt **`beyblade model`** und liegt **im Projektroot** (neben `import-nova-striker.bat`):

```
nova-bladers-main/
  beyblade model/
    storm-pegasus.glb    ← deine Datei
  import-nova-striker.bat
  start-rojo.bat
  ...
```

2. **Doppelklick** auf **`import-nova-striker.bat`**

Das Skript findet die GLB, vereinfacht sie und legt `NovaStriker.glb` in `tools/nova-striker-import/output/`.

---

## Option B — Manuell (PowerShell)

Im Projektordner:

```powershell
# GLB kopieren (Pfad anpassen falls nötig)
copy "beyblade model\*.glb" "tools\nova-striker-import\source\storm-pegasus.glb"

cd tools\nova-striker-import
npm install
npm run simplify
```

---

## Danach — Roblox Studio

1. **`start-rojo.bat`** starten → Studio → **Rojo Connect**
2. **File → Import 3D** → wähle:
   `tools\nova-striker-import\output\NovaStriker.glb`
3. **View → Command Bar** (oben)
4. Öffne **`tools\nova-striker-import\setup-in-studio.lua`** → **alles kopieren** → in Command Bar einfügen → **Enter**
5. **Play** → **Nova Striker** wählen

Du solltest Storm Pegasus als 3D-Bey in der Arena sehen.

---

## ZIP statt GLB?

Falls du eine **.zip** hast:
1. ZIP entpacken
2. Die **.glb** Datei in `beyblade model\` legen
3. `import-nova-striker.bat` erneut starten
