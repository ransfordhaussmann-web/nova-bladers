# AGENTS.md

## Cursor Cloud specific instructions

Nova Bladers is a Roblox (Luau) spin-arena fighter game plus three independent
Node.js sub-projects. There is **no root package manager / workspace** — each
Node sub-project has its own `package.json` + lockfile and must be installed
separately. There are **no automated tests, linters, or CI** anywhere in the repo.

### Services / sub-projects

| Sub-project | Path | Runtime | Run (dev) | Notes |
|-------------|------|---------|-----------|-------|
| Roblox game | `src/` | Roblox Studio + Rojo | `rojo serve default.project.json` (port 34872) | Core product. Real end-to-end play requires **Roblox Studio** (proprietary, Windows/macOS GUI) which **cannot run on this Linux VM**. `rojo serve` runs headlessly and serves the project tree, but there is no Studio to connect to here. |
| Mobile companion app | `mobile/` | Expo ~57 / React Native 0.86 | `npm run web` (browser) / `npm start` (Expo Go) | Runs fully on Linux via `react-native-web`. Serves on port 8081. Best way to demo/test on the VM. |
| Special-move preview | `preview/` | Node + Puppeteer | `npm run generate-videos` | Regenerates MP4 previews (needs `ffmpeg`, already on PATH; Puppeteer downloads Chromium). Static viewing: open `preview/index.html`. |
| Nova Striker import tool | `tools/nova-striker-import/` | Node CLI | `npm run simplify` | One-off GLB mesh optimizer. `simplify` needs a manually-supplied `source/storm-pegasus.glb` that is **not in the repo**, so it can't run out of the box. |

### Non-obvious notes

- **Rojo is not part of the npm dependency refresh.** It is a standalone binary
  (pinned to 7.4.4 in `aftman.toml`). If `rojo` is missing, install it directly:
  `curl -fsSL https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-linux-x86_64.zip -o /tmp/rojo.zip && unzip -o /tmp/rojo.zip -d /tmp/rojo-bin && sudo install /tmp/rojo-bin/rojo /usr/local/bin/rojo`
  (the repo's `aftman.toml` / `.bat` helpers target Windows).
- **Type checking** is the only static check available for the mobile app:
  `cd mobile && npx tsc --noEmit` (no dedicated npm script; `tsconfig.json` has `strict: true`).
- **Expo web in CI**: running `CI=1 npm run web` starts Metro without file
  watching (no hot reload). Omit `CI=1` for a normal dev server with reloads.
- The project docs are written in **German** (`README.md`, `docs/`, in-app text).
- Roblox `DataStore` persistence (`PlayerDataManager.lua`, `LeaderboardManager.lua`)
  only works in a **published** Roblox place with API access enabled — not locally.
