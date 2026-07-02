# Nova Bladers — PC Setup (Windows)

Schritt-für-Schritt-Anleitung für deinen Laptop: **Cursor**, **Roblox Studio** und **Rojo-Sync**.

> Dein bisheriger Ordner war vermutlich `C:\Users\hp\NovaBladers`.  
> Du kannst diesen Ordner weiterverwenden oder das Repo neu klonen.

---

## Schnellstart (3 Klicks)

1. **Doppelklick** auf `setup-pc.bat` — prüft Git, Node, Rojo
2. **Doppelklick** auf `start-rojo.bat` — startet Sync-Server
3. **Roblox Studio** → Plugins → **Rojo** → **Connect**

---

## Phase 1 — PC Grundsetup

### 1. Git installieren

Falls noch nicht installiert:

1. https://git-scm.com/download/win
2. Installer durchklicken (Standard-Einstellungen OK)
3. **PC neu starten** oder Terminal schließen und neu öffnen

Prüfen in PowerShell:

```powershell
git --version
```

### 2. Node.js installieren (optional, für Video-Vorschau)

1. https://nodejs.org/ → **LTS** herunterladen
2. Installieren

Prüfen:

```powershell
node --version
npm --version
```

### 3. Projekt in Cursor öffnen

**Option A — Du hast schon einen Ordner** (`C:\Users\hp\NovaBladers`):

```powershell
cd C:\Users\hp\NovaBladers
git remote add origin https://github.com/ransfordhaussmann-web/nova-bladers.git
git fetch origin
git checkout main
git pull origin main
```

Falls der Branch `cursor/bey-game-core-dbd8` die neuesten Features hat:

```powershell
git fetch origin
git checkout cursor/bey-game-core-dbd8
git pull origin cursor/bey-game-core-dbd8
```

**Option B — Neu klonen:**

1. Cursor öffnen → **Clone repo**
2. URL: `https://github.com/ransfordhaussmann-web/nova-bladers`
3. Ordner wählen, z. B. `C:\Users\hp\NovaBladers`
4. **Open project**

---

## Phase 2 — Rojo (Cursor ↔ Roblox Studio)

Rojo synchronisiert den Code aus dem Ordner `src/` automatisch in Roblox Studio.

### 1. Aftman installieren (Rojo-Installer)

1. https://github.com/LPGhatGuy/aftman/releases
2. `aftman-x86_64-pc-windows-msvc.zip` herunterladen
3. `aftman.exe` nach `C:\Users\DEINNAME\.aftman\bin\` kopieren
4. **PATH setzen:**
   - Windows-Suche: **„Umgebungsvariablen“**
   - Benutzervariablen → **Path** → **Neu**
   - `C:\Users\DEINNAME\.aftman\bin` eintragen
   - OK → Terminal neu starten

### 2. Rojo im Projekt installieren

Im Projektordner (PowerShell):

```powershell
cd C:\Users\hp\NovaBladers
aftman install
rojo --version
```

Oder einfach **`setup-pc.bat`** nochmal ausführen — das macht das automatisch.

### 3. Rojo-Plugin in Roblox Studio

1. **Roblox Studio** öffnen
2. **Toolbox** → **Creator Store** → nach **„Rojo“** suchen
3. Plugin von **Rojo** (rojo-rbx) installieren
4. Deinen **Nova-Bladers-Place** öffnen

> Beim ersten Mal: In Studio müssen die Ordner `ReplicatedStorage/NovaBladers`, `ServerScriptService` und `StarterPlayer/StarterPlayerScripts` existieren — Rojo legt sie beim Connect an bzw. überschreibt den Inhalt aus `src/`.

---

## Phase 3 — Täglicher Workflow

```
┌─────────────────┐     rojo serve      ┌──────────────────┐
│  Cursor         │ ──────────────────► │  Roblox Studio   │
│  src/*.lua      │     (live sync)     │  Play + testen   │
└─────────────────┘                     └──────────────────┘
         │                                       │
         └──────── preview/index.html ◄──────────┘
                    (Video-Vorschau)
```

### Jeden Tag:

1. **`start-rojo.bat`** doppelklicken (Fenster offen lassen!)
2. **Roblox Studio** → Plugins → **Rojo** → **Connect**
3. **Cursor** — Code in `src/` bearbeiten
4. **Studio** — Änderungen erscheinen automatisch → **Play** testen
5. **`preview/index.html`** — Special-Move-Videos zum Vergleich

### Wichtige Ordner

| Ordner | Inhalt |
|--------|--------|
| `src/ReplicatedStorage/NovaBladers/` | Bey-Logik, Special Moves, VFX |
| `src/ServerScriptService/` | Game Manager, Hub |
| `src/StarterPlayer/StarterPlayerScripts/` | Steuerung, HUD |
| `preview/` | Special-Move-Videos im Browser |

### Special Moves bearbeiten

| Datei | Was |
|-------|-----|
| `BeyConfig.lua` | Timings, Schaden, Phasen |
| `SpecialMoveRunner.lua` | Ablauf-Logik |
| `SpecialVFX.lua` | Partikel, Aura, Explosionen |
| `SpecialVFX.lua` + Studio Play | **E** drücken zum Testen |

---

## Probleme?

| Problem | Lösung |
|---------|--------|
| `rojo` nicht gefunden | Aftman + PATH prüfen, Terminal neu starten |
| Rojo Connect schlägt fehl | `start-rojo.bat` läuft? Firewall Port 34872? |
| Studio zeigt alten Code | Rojo Disconnect → Connect erneut |
| Git pull Fehler | `git stash` dann `git pull` |
| Kein Place in Studio | Neuen Place erstellen, Rojo verbindet trotzdem |

---

## Hilfe

- Rojo Docs: https://rojo.space/docs/v7/
- Repo: https://github.com/ransfordhaussmann-web/nova-bladers
