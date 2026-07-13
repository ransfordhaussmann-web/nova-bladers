
Import Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model name | Bey | Creator Store search hint |
|------------|-----|---------------------------|
| **NovaStriker** | Nova Striker | `spinning top attack blue` |
| **IronShell** | Iron Shell | `spinning top metal defense` |
| **VoltDash** | Volt Dash | `spinning top yellow lightning` |
| **ShadowBite** | Shadow Bite | `spinning top dark purple` |
| **BlazeOrbit** | Blaze Orbit | `spinning top fire red` |
| **CrystalGuard** | Crystal Guard | `spinning top crystal ice` |

## Studio import

1. Toolbox → Creator Store → search the hint above
2. Insert model, scale to ~3.5 studs wide, flat on ground
3. Rename to the **Model name** column
4. Move to: `ReplicatedStorage → NovaBladers → Models → <ModelName>`
5. Set **PrimaryPart** (or child named `Hull`)
6. Play — `BeyModelBuilder` clones this instead of the procedural mesh

## MeshId shortcut (no full model)

In `BeyCatalog.lua`, set `modelAssets.meshId = "rbxassetid://..."` on a bey entry.
Procedural layers are skipped; spin ring is still added automatically.

See `docs/BEY-MODELS.md` for Nova Striker Sketchfab import.
