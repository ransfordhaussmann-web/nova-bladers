# Bey Models — Studio Import

Import Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Folder | Bey |
|--------|-----|
| `NovaStriker` | Nova Striker |
| `IronShell` | Iron Shell |
| `VoltDash` | Volt Dash |
| `ShadowBite` | Shadow Bite |
| `FrostPrism` | Frost Prism |
| `BlazeRipper` | Blaze Ripper |

## Steps (Roblox Studio)

1. **Toolbox → Creator Store** → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, resize to ~3–4 studs wide
3. Move to `ReplicatedStorage/NovaBladers/Models/<FolderName>`
4. Set `PrimaryPart`, optional `Hull` part for collision
5. Rojo sync → game auto-clones on spawn

Without a Studio model, procedural 3D layers are built at runtime.

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for direct MeshId use.
