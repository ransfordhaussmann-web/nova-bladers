# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Forge** | Molten ring, 4 forge teeth, ember tip |
| **Azure Tide** | Wave segments, glass bubble shield, cyan spin ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `spin top`, `metal top`
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Note the **asset ID** from the model URL or properties
7. In `BeyCatalog.lua`, add to the bey entry:

```lua
modelAssets = {
    creatorStoreId = 1234567890,  -- full model from Creator Store
    targetSize = 3.5,
    -- meshId = "rbxassetid://...",  -- single MeshPart alternative
    -- textureId = "rbxassetid://...",  -- optional
},
```

8. Procedural layers are skipped when `creatorStoreId` or `meshId` is set; spin ring still added.

**Load order:** Studio `Models/` folder → `creatorStoreId` (runtime) → `meshId` → procedural fallback.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<BeyId>` (e.g. `IronShell`, `CrimsonForge`)
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part
5. `BeyModelBuilder` clones from folder when present

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef` / `modelAssets` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
