# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Fang** | 4 red attack blades, crimson neon ring |
| **Granite Fort** | Stone shell segments, slate rampart, heavy dual rings |
| **Solar Drift** | Sun disc, golden rays, wide stamina glow ring |
| **Phantom Edge** | Glass core, force-field ghost ring, cyan phantom blades |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

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
modelRef = {
    studioModelName = "CrimsonFang",  -- must match Models folder name
},
modelAssets = {
    creatorStoreSearch = "spinning top red attack blade",  -- Toolbox hint
    meshId = "rbxassetid://YOUR_ID_HERE",  -- optional: skip procedural mesh
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

8. Procedural layers are skipped when `meshId` is set; spin ring still added.

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<StudioModelName>`
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part
5. Set `modelRef.studioModelName` in `BeyCatalog.lua` to match the folder name

### Creator-Store Beys (optional meshes)

| Bey | `studioModelName` | Toolbox search (`modelAssets.creatorStoreSearch`) |
|-----|-------------------|---------------------------------------------------|
| Crimson Fang | `CrimsonFang` | spinning top red attack blade |
| Granite Fort | `GraniteFort` | spinning top heavy defense stone |
| Solar Drift | `SolarDrift` | spinning top gold sun stamina |
| Phantom Edge | `PhantomEdge` | spinning top phantom cyan |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <name>`

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
