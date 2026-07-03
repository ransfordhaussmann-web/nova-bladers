# Nova Bladers — Status & Überblick

**Stand:** Juli 2026 · Alles auf einen Blick

---

## Wo bist du?

| Was | Wo auf deinem PC |
|-----|------------------|
| **Dein Projekt** | `C:\Users\hp\Downloads\nova-bladers-main` |
| **ZIP (Backup)** | `C:\Users\hp\Downloads\nova-bladers-main.zip` |

---

## Was ist schon fertig (im Spiel)?

| Feature | Status |
|---------|--------|
| 4 Beyblades spielbar | ✅ |
| Special Moves mit Animationen | ✅ |
| Nova Striker Pegasus-Modell (einfach) | ✅ |
| Video-Vorschau im Browser (`preview/`) | ✅ (optional) |
| Sketchfab 3D-Import | ⏸ später |

---

## Was du JETZT brauchst (Minimum)

| Tool | Wofür | Status bei dir |
|------|-------|----------------|
| **Roblox Studio** | Spiel testen | vermutlich ✅ |
| **Rojo** | Code ↔ Studio Sync | ❌ fehlte zuletzt |
| **Rojo-Plugin** in Studio | Connect-Button | prüfen im Creator Store |

Git und Node.js sind **optional** (nur für Updates / Videos).

---

## EIN Schritt — alles installieren

Im Ordner `nova-bladers-main`:

**Doppelklick → `SETUP-ALLES.bat`**

Das Skript:
1. Installiert **Git**, **Node**, **Rojo** (über winget)
2. Prüft Projekt-Dateien
3. Schreibt **`STATUS.txt`** mit Ergebnis

Danach **Terminal schließen**, **`SETUP-ALLES.bat` nochmal** (falls Rojo noch fehlt).

---

## Spiel starten (3 Klicks)

1. **`start-rojo.bat`** — Fenster offen lassen
2. **Roblox Studio** → Plugins → **Rojo** → **Connect**
3. **Play** ▶ → Nova Striker wählen

---

## Später (nicht jetzt)

- Sketchfab GLB → `beyblade model\storm-pegasus.glb` → `import-nova-striker.bat`
- Neueste Version: `git clone https://github.com/ransfordhaussmann-web/nova-bladers.git`

---

## Hilfe-Dateien im Projekt

| Datei | Zweck |
|-------|-------|
| `SETUP-ALLES.bat` | Alles installieren + Status |
| `start-rojo.bat` | Sync starten |
| `STATUS.txt` | Wird nach Setup erzeugt |
| `docs/ORDNER-FINDEN.md` | Ordner suchen |

---

## Kurz-Zusammenfassung

Du hast das Projekt **entpackt** ✅  
**Rojo fehlte** noch ❌  
→ **`SETUP-ALLES.bat`** ausführen → **`start-rojo.bat`** → **Play**

Mehr nicht. Alles andere kann warten.
