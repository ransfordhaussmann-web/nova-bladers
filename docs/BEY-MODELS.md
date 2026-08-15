# Bey Models — 3D Setup

## What's in the game now

Six beys with layered 3D models built at runtime (procedural fallback) or cloned from Creator Store imports:

| Bey | Look |
|-----|------|
| **Nova Striker** | 3 attack blades, blue energy ring, metal core |
| **Iron Shell** | Heavy shell segments, green shield ring |
| **Volt Dash** | Wide flat ring, yellow lightning bolts |
| **Shadow Bite** | Dark aura, asymmetric fangs |
| **Blaze Comet** | Fiery comet tail, flame blades, orange neon ring |
| **Crystal Crown** | Glass crown spikes, crystal ring segments, shield |

Layers **spin visually** while the bey moves.

---

## Roblox Creator Store (optional better meshes)

### How to add a Creator Store model

1. Open **Roblox Studio**
2. **View → Toolbox → Creator Store**
3. Search: `spinning top`, `spin top`, `metal fight`
4. Insert a model into Workspace
5. Check size (~3–4 studs wide), orientation (flat on ground)
6. Move to `ReplicatedStorage/NovaBladers/Models/<ModelName>`
7. In `BeyCatalog.lua`, set `modelRef.studioModelName` to match the folder name

Alternatively, paste a **MeshId** into `modelAssets.meshId` on the bey entry.

### Hub Bey Gallery

The 3D Hub displays all six beys on pedestals near the Bey-Galerie zone. Imported Studio models appear automatically when present in the Models folder.

---

## Files

| File | Purpose |
|------|---------|
| `BeyModelBuilder.lua` | Builds 3D models per bey (procedural + import) |
| `BeyCatalog.lua` | Colors, stats, `modelRef` / `modelAssets` |
| `HubWorldBuilder.lua` | Gallery pedestals in 3D Hub |
