# Bey 3D Models (optional Studio import)

Procedural models are built at runtime. For higher-quality meshes, import a Creator Store or custom model into Studio:

```
ReplicatedStorage/NovaBladers/Models/
  NovaStriker/
  IronShell/
  VoltDash/
  ShadowBite/
  CrimsonFang/
  FrostHalo/
```

Each folder should be a **Model** named exactly as above (see `modelRef.studioModelName` in `BeyCatalog.lua`).

## Quick setup in Studio

1. **View → Toolbox → Creator Store** — search the `creatorStoreSearch` hint from `BeyCatalog.lua`
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move under `ReplicatedStorage/NovaBladers/Models/<BeyId>`
4. Set **PrimaryPart** (or name collision part `Hull`)
5. Play — `BeyModelBuilder` clones the import instead of procedural layers

Alternatively set `modelAssets.meshId` in the catalog for a single MeshPart asset.
