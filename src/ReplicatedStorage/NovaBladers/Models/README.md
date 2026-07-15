# Creator Store / Studio Models

Import spinning-top meshes from Roblox Studio Toolbox (Creator Store) or your own 3D files.

Place each model under `ReplicatedStorage → NovaBladers → Models` with the matching name:

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `CrimsonFang` | Crimson Fang |
| `FrostHalo` | Frost Halo |

## Import steps

1. Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (avoid UGC waist accessories)
3. Insert model, scale to ~3.5 studs wide, lay flat on arena
4. Rename to the **studio model name** from the table above
5. Move to `ReplicatedStorage/NovaBladers/Models/<name>`
6. Set **PrimaryPart** (or child part named `Hull`)

`BeyModelBuilder` auto-clones Studio models when present; otherwise procedural layers are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart instead.
