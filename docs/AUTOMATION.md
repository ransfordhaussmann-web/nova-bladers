# Cursor Automation — Audit & Setup

## Probleme der ersten Version (behoben)

| Problem | Status |
|---------|--------|
| Lokaler Windows-Pfad im Prompt (`C:\Users\hp\...`) | Behoben — Prompt nutzt jetzt Repo-Dateien |
| Roblox Studio MCP referenziert | Entfernt — nicht für Cloud-Automation geeignet |
| Kein `agentOptions` | Behoben |
| Prompt nicht versioniert | Behoben — `docs/automation-prompt.md` |
| Kein Git-Repo | Behoben — lokales Repo `C:\Users\hp\NovaBladers`, Branch `main` |
| Fehlende `gitConfig` | Teilweise — Branch `main` vorgefüllt; GitHub-Repo im Editor wählen |

## Korrekte Automation

| Feld | Wert |
|------|------|
| **Name** | Nova Bladers Auto Dev |
| **Trigger** | Alle 2 Stunden (`0 */2 * * *`) |
| **Prompt** | Inhalt aus `docs/automation-prompt.md` |
| **Memory** | Aktiviert |
| **Repo** | Dieses GitHub-Repo (nach Push) |

## Setup (einmalig)

1. ~~Git installieren~~ ✓ erledigt
2. ~~Lokales Repo + Commit~~ ✓ erledigt (`main`, Commit `de6c7d8`)
3. **Du musst noch:** Neues Repo auf GitHub erstellen und pushen:
   ```powershell
   cd C:\Users\hp\NovaBladers
   git remote add origin https://github.com/DEIN-USER/nova-bladers.git
   git push -u origin main
   ```
4. In Cursor Automation (Editor ist offen): **Repository** = dein GitHub-Repo, **Branch** = `main`
5. **Speichern** und **Aktivieren**

## Wichtig

- Cloud-Automation läuft im **Sandbox** — bearbeitet nur Dateien im Git-Repo
- Roblox Studio Scripts musst du manuell übernehmen oder später **Rojo** einrichten
- Ohne GitHub-Verknüpfung kann die Automation **nicht speichern/ausführen**
