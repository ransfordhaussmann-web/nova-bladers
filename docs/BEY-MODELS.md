# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (procedural fallback). Optional **Creator Store** or custom imports override the procedural mesh.

| Bey | Type | Look |
|-----|------|------|
| **Nova Striker** | Attack | 3 attack blades, blue energy ring, metal core |
| **Iron Shell** | Defense | Heavy shell segments, green shield ring |
| **Volt Dash** | Stamina | Wide flat ring, yellow lightning bolts |
| **Shadow Bite** | Balance | Dark aura, asymmetric fangs |
| **Crimson Fang** | Attack | 4 red fang blades, fast spin ring |
| **Granite Fort** | Defense | Stone fort segments, heavy crown |
| **Solar Drift** | Stamina | Sun disc, radiating rays |
| **Phantom Edge** | Balance | Translucent phantom blades |
| **Crystal Edge** | Attack | Ice crystal shards, frost ring |
| **Blaze Crown** | Balance | Flame spikes, crown ring |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `bey blade metal`
4. Insert a model you like into Workspace
5. Check size (~3–4 studs wide), orientation (flat on ground)
6. Rename to the bey's `studioModelName` (see table in `Models/README.md`)
7. Move to `ReplicatedStorage/NovaBladers/Models/`
8. Set **PrimaryPart** on the model (or child named `Hull`)
9. Play — procedural layers are skipped when the Studio model is found

### Alternative: meshId in catalog

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

### Import your own 3D file

1. Model in **Blender** → export **FBX** or **GLB**
2. Studio → **File → Import 3D**
3. Place under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Procedural 3D models + Studio model clone |
| `BeyCatalog.lua` | Colors, stats, `modelRef.studioModelName` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Import a Creator Store model for any bey and verify it replaces the procedural mesh
