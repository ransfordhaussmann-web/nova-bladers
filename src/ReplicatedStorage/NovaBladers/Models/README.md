
Import Creator Store models here for in-game use.

## Studio import

1. Toolbox → Creator Store → search term from `BeyCatalog.modelRef.creatorStoreSearch`
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to match `modelRef.studioModelName` (e.g. `CrimsonFang`, `FrostCrown`, `NovaStriker`)

## Optional meshId shortcut

Paste a Toolbox MeshId into `BeyCatalog.modelAssets.meshId` instead of importing a full model.

## Fallback

If no model folder exists, `BeyModelBuilder` builds a procedural 3D Bey automatically.
