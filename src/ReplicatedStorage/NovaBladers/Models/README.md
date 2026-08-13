# Bey model imports (Roblox Studio)

Place imported Creator Store or FBX models here. Rojo syncs this folder to
`ReplicatedStorage → NovaBladers → Models`.

| Folder name | Bey |
|-------------|-----|
| `NovaStriker` | Nova Striker (see `docs/SKETCHFAB-NOVA-STRIKER.md`) |
| `IronShell` | Iron Shell |
| `CrimsonFang` | Crimson Fang |
| `FrostCrown` | Frost Crown |

After import: set `PrimaryPart`, name collision part `Hull`, weld parts.
Procedural fallback builds run when no matching folder exists.

Optional: paste Creator Store `rbxassetid` into `BeyCatalog.modelAssets.meshId`.
