# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (no flat cylinder anymore):

| Bey | Look | Creator Store |
|-----|------|----------------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core | `Models/NovaStriker` or meshId |
| **Iron Shell** | Heavy shell segments, green shield ring | `Models/IronShell` or meshId |
| **Volt Dash** | Wide flat ring, yellow lightning bolts | `Models/VoltDash` or meshId |
| **Shadow Bite** | Dark aura, asymmetric fangs, purple core | `Models/ShadowBite` or meshId |
| **Ember Core** | Flame spikes, red neon ring | `Models/EmberCore` or meshId |
| **Tidal Ring** | Layered wave rings, teal segments | `Models/TidalRing` or meshId |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

We searched the Creator Store — most "beyblade" hits are **UGC accessories** (waist items), not game-ready spin tops. Fan games often use **free toolbox models** with mixed quality.

### Quick path: paste meshId in one file

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search using terms from `BeyCatalog.lua` → `modelRef.creatorStore.search`
4. Insert a model, scale to ~3–4 studs wide, lay flat on the arena
5. Copy **MeshId** from the main MeshPart
6. Paste in `src/ReplicatedStorage/NovaBladers/CreatorStoreConfig.lua`:

```lua
meshIds = {
    IronShell = "rbxassetid://YOUR_ID_HERE",
},
```

7. Rojo sync → Play → procedural layers are replaced by the store mesh + spin ring

### Studio model folder (best quality)

1. Insert Creator Store model into Workspace
2. Scale/orient flat (~3.5 stud diameter)
3. Move to `ReplicatedStorage → NovaBladers → Models → IronShell` (name matches `studioModelName`)
4. Set `PrimaryPart` or name collision part `Hull`
5. Procedural build is skipped when the folder model exists

### Per-bey catalog entry (alternative)

In `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, `modelRef`, optional `modelAssets` |
| `CreatorStoreConfig.lua` | Central meshId paste board for all beys |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
4. After pasting a meshId, re-test that bey to confirm the store mesh loads
