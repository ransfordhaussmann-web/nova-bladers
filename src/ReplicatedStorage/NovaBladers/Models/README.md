# Bey Model Imports (Creator Store / Studio)

Place imported spin-top models here as **Model** instances. `BeyModelBuilder` clones them when present; otherwise procedural layers are used.

| Catalog ID   | Folder name in `Models/` |
|--------------|--------------------------|
| NovaStriker  | NovaStriker              |
| IronShell    | IronShell                |
| VoltDash     | VoltDash                 |
| ShadowBite   | ShadowBite               |
| CrimsonFang  | CrimsonFang              |
| FrostCrown   | FrostCrown               |

## Creator Store workflow

1. Roblox Studio → **Toolbox → Creator Store** → search `spinning top` / `bey blade`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
4. Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart instead

## Import rotation

If a model stands upright, set in `modelRef`:

```lua
importRotation = CFrame.Angles(math.rad(-90), 0, 0),
```
