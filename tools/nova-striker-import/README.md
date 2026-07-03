# Nova Striker Import Tool

Automated pipeline for Nova Striker 3D model.

## Quick start

```bash
npm install
npm run all
```

Or double-click `import-nova-striker.bat` in repo root.

## What `npm run all` does

1. **download.mjs** — acquire source GLB:
   - `SKETCHFAB_API_TOKEN` → official Sketchfab download
   - Local GLB in `beyblade model/`, `assets/models/`, or `source/`
   - **Fallback:** `build-procedural-pegasus.mjs` (Storm Pegasus inspired, no login)
2. **simplify.mjs** — decimate for Roblox → `output/NovaStriker.glb`

## Output

| File | Purpose |
|------|---------|
| `output/NovaStriker.glb` | Import into Roblox Studio |
| `../../assets/models/NovaStriker.glb` | Committed copy for easy access |

## Studio setup

After **File → Import 3D**, run `setup-in-studio.lua` in Command Bar.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run download` | Acquire/build source GLB only |
| `npm run build-procedural` | Build Pegasus GLB without Sketchfab |
| `npm run simplify` | Simplify existing source |
| `npm run all` | Full pipeline |
| `npm run info` | Triangle count of source |
