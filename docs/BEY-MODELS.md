# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Fang** | Triple attack claws, red rage ring, fast spin layers |
| **Frost Crown** | Ice crown segments, glass spikes, frost aura shield |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Creator Store mesh slots (all 6 Beys)

Each bey has an optional Creator Store / Toolbox mesh slot in `CreatorStoreAssets.lua`.
Procedural 3D layers are used when `meshId` is `nil` (default — works without Studio imports).

| Bey | Studio model folder | Config key |
|-----|---------------------|------------|
| Nova Striker | `Models/NovaStriker` | `NovaStriker` |
| Iron Shell | `Models/IronShell` | `IronShell` |
| Volt Dash | `Models/VoltDash` | `VoltDash` |
| Shadow Bite | `Models/ShadowBite` | `ShadowBite` |
| Crimson Fang | `Models/CrimsonFang` | `CrimsonFang` |
| Frost Crown | `Models/FrostCrown` | `FrostCrown` |

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `beyblade`, `spinning top`, `bey blade metal`
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. In `CreatorStoreAssets.lua`, set `meshId` for the bey key:

```lua
IronShell = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.8, 1.3, 3.8),
    studioModelName = "IronShell",
},
```

7. Procedural layers are skipped when `meshId` is set; spin ring still added.

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
| `BeyCatalog.lua` | Colors, stats, special moves |
| `CreatorStoreAssets.lua` | Optional Creator Store mesh IDs per bey |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
