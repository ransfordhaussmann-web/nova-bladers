# Bey Models — Studio Import

Optional Creator Store / Sketchfab meshes. Without import, procedural builders in `BeyModelBuilder.lua` are used.

| Bey ID | Studio folder | Creator Store search |
|--------|---------------|----------------------|
| NovaStriker | `Models/NovaStriker` | spinning top blue attack |
| IronShell | `Models/IronShell` | spinning top defense metal |
| VoltDash | `Models/VoltDash` | spinning top yellow lightning |
| ShadowBite | `Models/ShadowBite` | spinning top dark purple |
| CrimsonEdge | `Models/CrimsonEdge` | spinning top red blade attack |
| FrostHalo | `Models/FrostHalo` | spinning top ice crystal |

## Import steps (Studio)

1. Toolbox → Creator Store → search query from table above
2. Insert model into `ReplicatedStorage/NovaBladers/Models/<BeyId>`
3. Set `PrimaryPart`, name collision part `Hull`, weld mesh parts
4. Or paste MeshId into `BeyCatalog.lua` → `modelAssets.meshId`

See `docs/BEY-MODELS.md` for full setup guide.
