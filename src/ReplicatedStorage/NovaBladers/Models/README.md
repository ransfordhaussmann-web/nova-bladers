
Import Creator Store or custom Bey models here for in-game use.

## Studio model names

| Bey ID | Folder name |
|--------|-------------|
| NovaStriker | NovaStriker |
| IronShell | IronShell |
| VoltDash | VoltDash |
| ShadowBite | ShadowBite |
| CrimsonBlaze | CrimsonBlaze |
| FrostOrbit | FrostOrbit |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store mesh (optional)

Instead of a full Model, set `modelAssets.meshId` in `BeyCatalog.lua`:

```lua
modelAssets = { meshId = "rbxassetid://YOUR_MESH_ID" },
```

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade".
