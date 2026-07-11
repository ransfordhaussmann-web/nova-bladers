# Bey Models — 3D Setup

## What's in the game now

Each bey is a **layered 3D model** built at runtime via `BeyModelBuilder.lua`:

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core |
| **Iron Shell** | Heavy shell segments, green shield ring |
| **Volt Dash** | Wide flat ring, yellow lightning bolts |
| **Shadow Bite** | Dark aura, asymmetric fangs |
| **Crimson Forge** | Hammer head, anvil ring segments, ember glow |
| **Frost Prism** | Crystal facets, ice ring, frost aura |

Layers **spin visually** while the bey moves.

---

## Roblox Creator Store (optional better meshes)

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `metal top`, `arena fighter`
4. Insert a model into Workspace
5. Check size (~3–4 studs wide), orientation (flat on ground)
6. Move to `ReplicatedStorage/NovaBladers/Models/<BeyId>`
7. Or copy **MeshId** into `BeyCatalog.lua`:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID_HERE",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

8. Procedural layers are skipped when `meshId` or a Studio model clone is found.

### Studio model import (best quality)

1. Export from Blender as **FBX** or import GLB via Studio
2. Place under `ReplicatedStorage/NovaBladers/Models/CrimsonForge` (or `FrostPrism`)
3. Set `PrimaryPart`, weld parts, optional `Hull` collision part
4. `BeyCatalog.modelRef.studioModelName` must match the folder name

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D layered models per bey |
| `BeyCatalog.lua` | Colors, stats, optional `modelRef` / `modelAssets` |
| `Models/README.md` | Studio import naming guide |
