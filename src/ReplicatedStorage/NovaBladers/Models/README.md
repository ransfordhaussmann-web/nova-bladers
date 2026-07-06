# Bey Models (Studio Import)

Import Creator Store or Sketchfab models here for in-game use.
Procedural fallbacks exist if no model is present.

## Expected model names

| Bey ID        | Studio Model Name | Type    |
|---------------|-------------------|---------|
| NovaStriker   | NovaStriker       | Attack  |
| IronShell     | IronShell         | Defense |
| VoltDash      | VoltDash          | Stamina |
| ShadowBite    | ShadowBite        | Balance |
| CrimsonBlaze  | CrimsonBlaze      | Attack  |
| FrostOrbit    | FrostOrbit        | Defense |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Creator Store meshId (optional)

Set `modelAssets.meshId` in `BeyCatalog.lua` instead of importing a Model:

```lua
modelAssets = { meshId = "rbxassetid://YOUR_ASSET_ID" },
```

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade" (rename to Nova Bladers IP in-game).
