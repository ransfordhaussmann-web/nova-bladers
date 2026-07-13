# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core, glass tip |
| **Iron Shell** | Heavy shell segments, green shield ring, dual spin layers |
| **Volt Dash** | Wide flat ring, yellow lightning bolts, fast outer glow |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple bit-beast core |
| **Crimson Blaze** | Flame spikes, ember ring, heat glow (Attack) |
| **Frost Crown** | Ice segments, crown spikes, frost shield (Defense) |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

All 6 beys support optional Creator Store meshes via `modelRef` (Studio Models folder) or `modelAssets.meshId`.

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

### Studio Models folder (recommended)

Place imported Creator Store or custom models under `ReplicatedStorage/NovaBladers/Models/`:

| Model name | Bey |
|------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonBlaze` | Crimson Blaze |
| `FrostCrown` | Frost Crown |

`BeyModelBuilder` clones from this folder when present; otherwise uses procedural layers.
Optionally set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart import.

### Nova Striker (Sketchfab reference)

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
