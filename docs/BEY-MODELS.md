# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Fang** | 4 red fang blades, crimson neon ring, aggressive attack profile |
| **Frost Crown** | Ice crown segments, crystal spikes, frosted glass shield ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search using the bey's `creatorStoreQuery` in `BeyCatalog.lua` (e.g. `spinning top red attack blade`)
4. Insert a model you like into Workspace
5. Check size (should be ~3–4 studs wide), orientation (flat on ground)
6. Either:
   - **Option A — MeshId:** Right-click mesh → copy **MeshId** → add to catalog:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

   - **Option B — Studio model:** Rename to the bey id (e.g. `CrimsonFang`) and place under `ReplicatedStorage/NovaBladers/Models/`

7. Procedural layers are skipped when a store mesh or Studio model is found; spin ring still added.

### Bey → Studio model folder

| Bey ID | Models folder name | Creator Store search hint |
|--------|-------------------|---------------------------|
| NovaStriker | `NovaStriker` | spinning top blue attack |
| IronShell | `IronShell` | spinning top metal defense |
| VoltDash | `VoltDash` | spinning top yellow lightning |
| ShadowBite | `ShadowBite` | spinning top dark purple |
| CrimsonFang | `CrimsonFang` | spinning top red attack blade |
| FrostCrown | `FrostCrown` | spinning top ice crystal |

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX** or **GLB**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<BeyId>`
4. Set **PrimaryPart**, weld parts, name `Hull` on collision part
5. Play — the game auto-clones this model instead of the procedural bey

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef` / optional `modelAssets` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
