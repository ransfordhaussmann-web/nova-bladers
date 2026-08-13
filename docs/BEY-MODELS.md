# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Blaze** | Flame spikes, heat layer, ember tip |
| **Frost Crown** | Ice crown spikes, frost ring, glass outer shell |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### Studio model folder (recommended)

1. Import mesh via **Toolbox → Creator Store** or **File → Import 3D**
2. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
3. In `BeyCatalog.lua`, set `modelRef.studioModelName` to match the folder name
4. Procedural layers are skipped when the Studio model is found; spin ring still added

See `src/ReplicatedStorage/NovaBladers/Models/README.md` for all model names.

### Single mesh asset (quick test)

1. Insert a mesh from **Toolbox → Creator Store** (search: `spinning top`)
2. Copy **MeshId** from the mesh part
3. In `BeyCatalog.lua`, add:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Procedural layers are skipped when `meshId` is set; spin ring still added.

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, optional `modelAssets` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
