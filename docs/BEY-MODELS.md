# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Starfall Edge** | 4 star blades, fiery orange ring |
| **Stone Halo** | Concrete shell segments, floating halo ring |
| **Thunder Coil** | Nested electric coils, cyan outer glow |
| **Night Maw** | 4 crimson fangs, blood aura ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

All 8 Beys have `modelRef` entries in `BeyCatalog.lua` for optional Creator Store imports.

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most spin-top hits are **UGC accessories** (waist items), not game-ready arena tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search using `modelRef.creatorStoreQuery` from `BeyCatalog.lua` (e.g. `spinning top fire orange`)
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
7. Or: copy **MeshId** and set `modelAssets.meshId` in the catalog

```lua
modelRef = {
    studioModelName = "StarfallEdge",
    targetSize = 3.5,
    creatorStoreQuery = "spinning top fire orange",
},
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",  -- optional
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

8. Procedural layers are skipped when a Studio model or `meshId` is found; spin ring still added.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part

See `src/ReplicatedStorage/NovaBladers/Models/README.md` for the full slot table.

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
3. Scroll through all 8 beys in the selection menu
4. Compare procedural vs imported models in Training mode
