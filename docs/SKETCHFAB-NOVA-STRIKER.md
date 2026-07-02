# Nova Striker — Storm Pegasus 3D Model

Visual reference: [Storm Pegasus 105 RF on Sketchfab](https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660) by IcaroAndradeOliveira1.

> **Note:** This is fan Beyblade IP used as a visual reference. Nova Striker remains our original in-game name.

## 1. View in browser (no Studio)

Open **`preview/nova-striker-3d.html`** — interactive 3D viewer (Sketchfab embed).

Or open **`preview/bey-showcase.html`** — Nova Striker card includes the same 3D viewer.

## 2. Use in Roblox Studio (in-game 3D)

Roblox **cannot** load Sketchfab URLs at runtime. You must **download and import** the mesh once:

### Download

1. Open https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660
2. Click **Download 3D Model** (free Sketchfab account required)
3. Choose **glTF** or **GLB** (recommended for Roblox — textures work better than FBX)

### Import to Studio

1. **File → Import 3D** → select the `.glb` or `.gltf` file
2. Scale: aim for **~3.5 studs wide**, flat on the arena floor
3. Rename the model to **`NovaStriker`**
4. Move it to: `ReplicatedStorage → NovaBladers → Models → NovaStriker`
5. Set **PrimaryPart** on the model (or a child part named `Hull`)
6. **Play** — the game auto-clones this model instead of the procedural bey

### Triangle count

The Sketchfab model has **~763k triangles** — too heavy for Roblox. Before import:

- Use [Blender](https://www.blender.org/) → Decimate modifier → target **~10k–20k** tris
- Or use Studio import and merge/simplify meshes

### Rojo sync (optional)

After import in Studio, export the model:

1. Right-click `Models/NovaStriker` → **Save to File** → `assets/models/NovaStriker.rbxmx`
2. Place in repo — Rojo will sync it on Connect

## 3. Credit

3D model: **Storm Pegasus 105 RF** by [@andradeoliveiraicaro785](https://sketchfab.com/andradeoliveiraicaro785) on Sketchfab.
