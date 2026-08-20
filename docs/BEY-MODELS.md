# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Blaze Drift** | Flame blades, ember ring, heat glow |
| **Frost Crown** | Ice crystal spikes, crown ring, frost shell |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Creator Store model import

Each bey has a `modelRef.studioModelName` in `BeyCatalog.lua`. Import a Creator Store or custom model in Studio under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`. Procedural layers are used as fallback when no model is found.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `spin top`, `metal top`
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Move the model to `ReplicatedStorage/NovaBladers/Models/<BeyId>` (e.g. `BlazeDrift`)
7. Set `PrimaryPart`, weld parts, optionally name collision part `Hull`
8. Play — `BeyModelBuilder` clones and scales via `modelRef.targetSize`

Alternatively, set a direct mesh ID in the catalog:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

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
3. Compare all 6 beys in Training mode
