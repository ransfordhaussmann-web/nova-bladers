# Bey 3D Models (Studio Import)

Import Creator Store or custom spinning-top meshes here for in-game use.

## Folder layout

```
ReplicatedStorage/NovaBladers/Models/
├── NovaStriker    (Model)
├── CrimsonFang    (Model) — optional Creator Store import
└── FrostCrown     (Model) — optional Creator Store import
```

Procedural fallbacks exist for all Beys when no Model is present.

## Creator Store import

1. Roblox Studio → **Toolbox** → **Creator Store** → search "spinning top"
2. Insert model into `ReplicatedStorage/NovaBladers/Models/`
3. Rename to match `modelRef.studioModelName` in `BeyCatalog.lua`
4. Optional: set `PrimaryPart` or a part named `Hull`

Alternatively, paste a MeshId into `BeyCatalog.modelAssets`:

```lua
modelAssets = {
	meshId = "rbxassetid://YOUR_MESH_ID",
	textureId = nil,
	size = Vector3.new(3.6, 1.2, 3.6),
},
```

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via the one-click tool.
