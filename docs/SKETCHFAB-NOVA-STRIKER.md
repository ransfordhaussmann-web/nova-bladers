# Nova Striker — Storm Pegasus 3D Model

Visual reference: [Storm Pegasus 105 RF — versão exclusiva](https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e) by IcaroAndradeOliveira1.

> **Note:** Fan Beyblade IP as visual reference. In-game name remains **Nova Striker**.

## Nach Sketchfab-Login (dein Modell)

Du bist eingeloggt — super. Dieses Modell ist **downloadbar**:

https://sketchfab.com/3d-models/storm-pegasus-105-rf-versao-exclusiva-2093ae37cc624534902d7b92fee88f4e

### Option A — API-Token (vollautomatisch)

1. Öffne https://sketchfab.com/settings/password
2. Klicke **Generate Token**
3. Kopiere `tools/nova-striker-import/.env.example` → `.env`
4. Token eintragen: `SKETCHFAB_API_TOKEN=dein_token`
5. `import-nova-striker.bat` oder `npm run fetch && npm run simplify`

### Option B — Manueller Download (einfach)

1. Auf der Modellseite: **Download 3D Model** → **GLB**
2. Speichern als: `beyblade model/storm-pegasus.glb`
3. `import-nova-striker.bat` starten

## Fully automatic (no manual download)

**Double-click `import-nova-striker.bat`** — or run:

```bash
cd tools/nova-striker-import
npm install
npm run all
```

This will:
1. Use your Sketchfab GLB if found in `beyblade model/` or `source/`
2. Or use `SKETCHFAB_API_TOKEN` for official API download
3. Or **auto-build** a Storm-Pegasus-inspired GLB (no login needed)
4. Simplify mesh for Roblox → `output/NovaStriker.glb` + `assets/models/NovaStriker.glb`

**In-game without Studio:** The improved procedural Nova Striker model runs immediately when you press Play (no import required).

## Optional: Sketchfab original

If you downloaded the original Storm Pegasus GLB to your PC:

1. Put it in `beyblade model/` or `tools/nova-striker-import/source/storm-pegasus.glb`
2. Run `import-nova-striker.bat` again — it replaces the auto-built model

Or set `SKETCHFAB_API_TOKEN` (from Sketchfab Settings → Password & API) and run `npm run all`.

## Studio import (optional, higher detail)

1. **File → Import 3D** → `assets/models/NovaStriker.glb`
2. **Command Bar** → paste `tools/nova-striker-import/setup-in-studio.lua` → Enter
3. **Play** → pick Nova Striker

## Credit

3D reference: **Storm Pegasus 105 RF** by [@andradeoliveiraicaro785](https://sketchfab.com/andradeoliveiraicaro785) on Sketchfab.
