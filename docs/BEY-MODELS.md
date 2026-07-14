# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime (procedural fallback) or cloned from **Creator Store imports** in Studio.

| Bey | Look | Creator Store folder |
|-----|------|----------------------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core | `Models/NovaStriker` |
| **Iron Shell** | Heavy shell segments, green shield ring | `Models/IronShell` |
| **Volt Dash** | Wide flat ring, yellow lightning bolts | `Models/VoltDash` |
| **Shadow Bite** | Dark aura, asymmetric fangs | `Models/ShadowBite` |
| **Crimson Edge** | Flame blades, crimson spin ring | `Models/CrimsonEdge` |
| **Frost Halo** | Ice segments, crystal halo | `Models/FrostHalo` |

Layers **spin visually** while the bey moves (RPM affects spin speed + ring opacity).

---

## Roblox Creator Store (optional better meshes)

### How to add a Creator Store model per Bey

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search using the bey's `searchTerms` from `BeyCatalog.lua` (e.g. `spinning top`, `red top`)
4. Insert a model into Workspace — check size (~3–4 studs wide), flat on ground
5. Move the model to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
   - Example: `Models/CrimsonEdge` for Crimson Edge
6. Play — `BeyModelBuilder` auto-clones the Studio model; procedural layers are the fallback

### Alternative: meshId only

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
| `BeyModelBuilder.lua` | Procedural build + Studio clone + external mesh |
| `BeyCatalog.lua` | Stats, colors, `modelRef`, `searchTerms` |
| `BeyController.lua` | Physics on hull + spin animation |

---

## Test in Studio

1. `start-rojo.bat` → Rojo Connect
2. Play → pick a bey → watch spin layers rotate
3. Compare all 6 beys in Training mode
