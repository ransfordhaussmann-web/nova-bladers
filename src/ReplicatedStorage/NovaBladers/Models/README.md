# Bey Models (Studio import)

Place imported Creator Store or custom 3D models here as **Model** instances.
`BeyModelBuilder` clones them when `modelRef.studioModelName` matches the folder name.

| Folder name   | Bey           |
|---------------|---------------|
| NovaStriker   | Nova Striker  |
| IronShell     | Iron Shell    |
| VoltDash      | Volt Dash     |
| ShadowBite    | Shadow Bite   |
| CrystalTide   | Crystal Tide  |
| BlazeCore     | Blaze Core    |

## Creator Store workflow

1. Studio → Toolbox → Creator Store → search `spinning top`
2. Insert model, scale to ~3–4 studs wide, lay flat
3. Move to this folder and rename to the table above
4. Or copy **MeshId** into `BeyCatalog.lua` → `modelAssets.meshId`

See `docs/BEY-MODELS.md` for full setup.
