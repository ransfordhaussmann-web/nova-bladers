# Creator Store Model Imports

Place imported Creator Store or custom 3D models here as **Model** instances.
`BeyModelBuilder` clones from this folder when `studioModelName` matches.

## Folder structure

```
ReplicatedStorage/NovaBladers/Models/
  NovaStriker      (optional — Sketchfab import, see docs/SKETCHFAB-NOVA-STRIKER.md)
  IronShell
  VoltDash
  ShadowBite
  CrimsonForge
  FrostCrown
```

## How to import from Creator Store

1. Roblox Studio → View → Toolbox → **Creator Store**
2. Search using `creatorStoreQuery` from `BeyCatalog.lua` (e.g. `spinning top attack red metal`)
3. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
4. Move to `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
5. Set `PrimaryPart` or name collision part `Hull`, weld child parts
6. Play — procedural fallback is used if folder/model is missing

## Catalog fields

| Field | Purpose |
|-------|---------|
| `studioModelName` | Folder name under Models/ |
| `creatorStoreQuery` | Toolbox search hint for Studio import |
| `targetSize` | Auto-scale to arena diameter (studs) |
| `importRotation` | Optional CFrame rotation after import |

Procedural 3D layers are built automatically when no Studio model is present.
