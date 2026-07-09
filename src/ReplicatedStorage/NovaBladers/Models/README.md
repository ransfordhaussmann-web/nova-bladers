
Optional Creator Store / imported 3D models for in-game use.

Place each model under `ReplicatedStorage → NovaBladers → Models` with the exact name below.
If a model exists, procedural layers are skipped automatically.

| Studio model name | Bey |
|-------------------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `FrostPrism` | Frost Prism |
| `BlazeRipper` | Blaze Ripper |

## How to import (Creator Store)

1. Roblox Studio → **View → Toolbox → Creator Store**
2. Search: `spinning top`, `bey blade metal` (pick a free model ~3–4 studs wide)
3. Insert into Workspace, orient flat on the ground
4. Rename to the **Studio model name** from the table above
5. Move to `ReplicatedStorage/NovaBladers/Models/`
6. Press Play — the imported mesh replaces the procedural build

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` (see `docs/BEY-MODELS.md`).
