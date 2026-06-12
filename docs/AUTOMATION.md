# Cursor Automation — Audit & Setup

## Probleme der ersten Version (behoben)

| Problem | Status |
|---------|--------|
| Lokaler Windows-Pfad im Prompt (`C:\Users\hp\...`) | Behoben — Prompt nutzt jetzt Repo-Dateien |
| Roblox Studio MCP referenziert | Entfernt — nicht für Cloud-Automation geeignet |
| Kein `agentOptions` | Behoben |
| Prompt nicht versioniert | Behoben — `docs/automation-prompt.md` |
| Kein Git-Repo | In Arbeit — siehe Setup unten |
| Fehlende `gitConfig` | Muss im Editor: GitHub-Repo verknüpfen |

## Korrekte Automation

| Feld | Wert |
|------|------|
| **Name** | Nova Bladers Auto Dev |
| **Trigger** | Alle 2 Stunden (`0 */2 * * *`) |
| **Prompt** | Inhalt aus `docs/automation-prompt.md` |
| **Memory** | Aktiviert |
| **Repo** | Dieses GitHub-Repo (nach Push) |

## Setup (einmalig)

1. Git installieren (falls noch nicht): `winget install Git.Git --source winget`
2. In diesem Ordner: `git init && git add . && git commit -m "Initial Nova Bladers"`
3. Neues Repo auf GitHub erstellen und pushen
4. In Cursor Automation: **Repository** = dein GitHub-Repo, **Branch** = `main`
5. **Speichern** und **Aktivieren**

## Wichtig

- Cloud-Automation läuft im **Sandbox** — bearbeitet nur Dateien im Git-Repo
- Roblox Studio Scripts musst du manuell übernehmen oder später **Rojo** einrichten
- Ohne GitHub-Verknüpfung kann die Automation **nicht speichern/ausführen**
