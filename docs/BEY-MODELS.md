# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look | Special |
|-----|------|---------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip | Nova Meteor Shower |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers | Iron Vault Lock |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow | Volt Sonic Tempest |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core | Shadow Eclipse Fang |
| **Crimson Edge** | Serrated flame blades, orange fire ring | Blaze Spiral Drive |
| **Frost Core** | Hexagonal ice shell, crystal spikes, glass shield | Glacier Aegis |

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
6. Right-click mesh → copy **MeshId** (or note asset ID from URL)
7. In `BeyCatalog.lua`, add to the bey entry:

```lua
modelRef = {
    studioModelName = "CrimsonEdge",  -- folder name under Models/
    targetSize = 3.6,
},
-- OR direct mesh:
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

8. Procedural layers are skipped when a Studio model or `meshId` is found; spin ring still added.

### Studio folder import (recommended)

1. Import 3D model in Studio (**File → Import 3D**)
2. Rename to match `modelRef.studioModelName` (e.g. `CrimsonEdge`)
3. Move to `ReplicatedStorage → NovaBladers → Models → CrimsonEdge`
4. Set **PrimaryPart** (or name collision part `Hull`)
5. Play — game auto-clones instead of procedural build

All 6 beys have `modelRef.studioModelName` configured:

| Bey | Studio folder |
|-----|---------------|
| Nova Striker | `Models/NovaStriker` |
| Iron Shell | `Models/IronShell` |
| Volt Dash | `Models/VoltDash` |
| Shadow Bite | `Models/ShadowBite` |
| Crimson Edge | `Models/CrimsonEdge` |
| Frost Core | `Models/FrostCore` |

### Import your own 3D file (best quality)

1. Model in **Blender** (or similar) → export **FBX** or **GLB**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Set `PrimaryPart`, weld parts, name `Hull` on collision part

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
