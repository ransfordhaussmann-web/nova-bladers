# Creator Store / Imported Bey Models

Place imported Toolbox or FBX models here. `BeyModelBuilder` clones by `modelRef.studioModelName` from `BeyCatalog`.

| studioModelName | Bey | Toolbox search hint |
|-----------------|-----|---------------------|
| NovaStriker | Nova Striker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | Iron Shell | beyblade defense metal shell |
| VoltDash | Volt Dash | beyblade stamina spinning top |
| ShadowBite | Shadow Bite | beyblade balance dark |
| CrimsonVortex | Crimson Vortex | beyblade attack red vortex |
| GlacierMantle | Glacier Mantle | beyblade ice frost defense |

## Studio setup

1. Toolbox → Creator Store → search hint from table
2. Insert model into Workspace, scale to ~3–4 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Optional: set `PrimaryPart`, name collision part `Hull`
5. Rojo sync or Play — procedural fallback runs if model missing

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a Model folder.
