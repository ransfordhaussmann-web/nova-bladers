
Optional Creator Store / Studio imports for in-game Bey meshes.

| Model name | Bey | Import path |
|------------|-----|-------------|
| NovaStriker | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| FrostCrown | Frost Crown | ReplicatedStorage → NovaBladers → Models → FrostCrown |
| CrimsonFang | Crimson Fang | ReplicatedStorage → NovaBladers → Models → CrimsonFang |

After Studio import, `BeyModelBuilder` clones from `Models/<studioModelName>`.
Without import, procedural builders in `BeyModelBuilder.lua` are used.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` (Toolbox → Creator Store → rbxassetid).
