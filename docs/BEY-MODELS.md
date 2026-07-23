# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Frost Crown** | Ice crystal spikes, frost ring, pale glass crown |
| **Ember Core** | Magma core, flame petals, fast heat ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `spin top`, `metal top` (avoid official IP names)
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

### Import via Models folder (preferred)

1. Model in **Blender** (or similar) → export **FBX** or **GLB**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<BeyId>` (e.g. `FrostCrown`)
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part
5. `BeyModelBuilder` clones from `Models/` when `modelRef.studioModelName` matches

All 6 beys have `modelRef.studioModelName` set — drop matching Studio models to override procedural meshes.

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef`, optional `modelAssets` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
