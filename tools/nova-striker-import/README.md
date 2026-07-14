# Nova Striker — Sketchfab → Roblox Import Tool

Automates **mesh simplification** (763k → ~15k triangles) for Roblox.

## Quick start (Windows)

1. **Double-click** `import-nova-striker.bat` (in repo root)
2. Browser opens Sketchfab → **Download → GLB**
3. Save file to: `tools/nova-striker-import/source/storm-pegasus.glb`
4. Press Enter in the script window → simplified `NovaStriker.glb` is created
5. Follow Studio steps shown on screen

## Manual commands

```bash
cd tools/nova-striker-import
npm install
# Put downloaded GLB in source/storm-pegasus.glb
npm run simplify
```

Output: `output/NovaStriker.glb`

## Roblox Studio (after simplify)

1. **File → Import 3D** → select `output/NovaStriker.glb`
2. In Studio **Command Bar** (View → Command Bar), paste contents of **`setup-in-studio.lua`**
3. Press Enter — model moves to `ReplicatedStorage.NovaBladers.Models.NovaStriker`
4. **Play** — Nova Striker uses the real mesh

## Sketchfab source

https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660

Credit: IcaroAndradeOliveira1

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No download button on Sketchfab | Create free Sketchfab account |
| Textures missing in Studio | Use **GLB** not FBX |
| Model too big/small in game | Edit `targetSize` in BeyCatalog modelRef |
| Model stands upright | `setup-in-studio.lua` rotates flat automatically |
