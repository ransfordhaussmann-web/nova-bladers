# Nova Bladers — Studio Model Slots

Optional Creator Store / imported 3D meshes. Procedural models are used when no folder model exists.

| Folder name | Bey | Creator Store search |
|-------------|-----|----------------------|
| `NovaStriker` | Nova Striker | spinning top blue attack |
| `IronShell` | Iron Shell | spinning top metal defense |
| `VoltDash` | Volt Dash | spinning top yellow lightning |
| `ShadowBite` | Shadow Bite | spinning top dark purple |
| `CrimsonFang` | Crimson Fang | spinning top red attack blade |
| `FrostCrown` | Frost Crown | spinning top ice crystal |

## Import steps

1. Studio → **Toolbox → Creator Store** (or **File → Import 3D**)
2. Scale to ~3.5 studs wide, flat on arena floor
3. Rename model to the folder name above
4. Move to: `ReplicatedStorage → NovaBladers → Models → <FolderName>`
5. Set **PrimaryPart** (or child part named `Hull`)
6. Play — game auto-clones instead of procedural build

See `docs/BEY-MODELS.md` for `modelAssets.meshId` alternative.
