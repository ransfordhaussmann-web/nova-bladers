# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Fang** | 4 jagged blades, blood-red neon ring, aggressive attack profile |
| **Glacier Shield** | Ice shell segments, frost spikes, heavy glass shield ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

### Creator Store import (Crimson Fang, Glacier Shield)

Both new beys support optional meshes via `modelRef` (Studio folder clone) or `modelAssets.meshId` (Creator Store):

1. Import model into `ReplicatedStorage/NovaBladers/Models/CrimsonFang` (or `GlacierShield`)
2. Or set `modelAssets.meshId = "rbxassetid://..."` in `BeyCatalog.lua`
3. Procedural fallback builds automatically when no import/meshId is present

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `beyblade`, `spinning top`, `bey blade metal`
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Right-click mesh → copy **MeshId** (or note asset ID from URL)
7. In `BeyCatalog.lua`, add to the bey entry:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
    -- textureId = "rbxassetid://...",  -- optional
},
```

8. Procedural layers are skipped when `meshId` is set; spin ring still added.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/NovaStriker`
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part
5. Future: clone from folder instead of procedural build

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
3. Compare all 4 beys in Training mode
