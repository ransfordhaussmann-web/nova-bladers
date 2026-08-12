# Bey Model Import Slots

Place Creator Store or imported 3D models under `ReplicatedStorage → NovaBladers → Models`.
Each bey clones from a folder matching `modelRef.studioModelName` in `BeyCatalog.lua`.

| Studio folder | Bey | Fallback |
|---------------|-----|----------|
| `NovaStriker` | Nova Striker | Procedural attack blades |
| `IronShell` | Iron Shell | Procedural shell segments |
| `VoltDash` | Volt Dash | Procedural stamina ring |
| `ShadowBite` | Shadow Bite | Procedural dark fangs |
| `StarfallEdge` | Starfall Edge | Procedural star points |
| `StoneHalo` | Stone Halo | Procedural stone halo |
| `ThunderCoil` | Thunder Coil | Procedural coil spirals |
| `NightMaw` | Night Maw | Procedural jaw fangs |

## Import from Creator Store

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `spin top`, `arena fighter`
3. Insert model, scale to ~3.5 studs wide, flat on arena floor
4. Rename to the folder name above (e.g. `StarfallEdge`)
5. Move to `ReplicatedStorage/NovaBladers/Models/`
6. Set **PrimaryPart** (or child named `Hull`)

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` instead of a full model folder.

## Import GLB / FBX

1. **File → Import 3D** → select file
2. Follow steps 4–6 above

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
