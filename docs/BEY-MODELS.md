# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Blaze Orbit** | Ember ring, 4 flame spikes, fast orange spin layer |
| **Crystal Guard** | Glass crystal segments, prism shield, ice spin ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

All six beys support **Creator Store** or **Models-folder** import via `modelRef` in `BeyCatalog.lua`.

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search the `creatorStoreQuery` from `BeyCatalog.lua` (e.g. `spinning top fire red`)
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Either:
   - **Full model:** rename to `studioModelName`, move to `ReplicatedStorage/NovaBladers/Models/`
   - **Single mesh:** copy **MeshId** and set in catalog:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
    -- textureId = "rbxassetid://...",  -- optional
},
```

7. Procedural layers are skipped when a Studio model or `meshId` is present; spin ring still added.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX** or **GLB**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part
5. Play — game auto-clones from folder instead of procedural build

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef`, optional `modelAssets` |
| `BeyController.lua` | Physics on hull + spin animation |
| `Models/README.md` | Per-bey import names and search hints |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
4. Optional: import Creator Store mesh for Blaze Orbit or Crystal Guard
