# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crystal Vortex** | Glass core, 6 crystal shards, prism ring |
| **Ember Ring** | Flame blades, fire ring, outer ember glow |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search using the bey's `creatorStore.searchTerms` in `BeyCatalog.lua` (e.g. `spinning top crystal`, `flame top`)
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Move the model to `ReplicatedStorage/NovaBladers/Models/<BeyId>` (e.g. `CrystalVortex`)
7. Set `PrimaryPart`, weld parts, optional `Hull` on collision part
8. On next spawn, `BeyModelBuilder` clones from `Models/` when present (procedural fallback otherwise)

**Alternative — single MeshPart:**

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
    -- textureId = "rbxassetid://...",  -- optional
},
```

Procedural layers are skipped when `meshId` or a `Models/` clone exists; spin ring still added.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/NovaStriker` (or matching `modelRef.studioModelName`)
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part

---

## Catalog metadata per bey

| Field | Purpose |
|-------|---------|
| `modelRef.studioModelName` | Folder name under `Models/` for Studio import |
| `modelRef.targetSize` | Auto-scale imported mesh to arena size |
| `creatorStore.searchTerms` | Suggested Toolbox search strings |
| `modelAssets.meshId` | Optional single MeshPart from Creator Store |

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef`, `creatorStore` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
