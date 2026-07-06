# Bey Models (Creator Store / Studio Import)

Import Creator Store or custom meshes into Roblox Studio under:

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Expected model folders

| ModelName     | Bey              |
|---------------|------------------|
| NovaStriker   | Nova Striker     |
| IronShell     | Iron Shell       |
| VoltDash      | Volt Dash        |
| ShadowBite    | Shadow Bite      |
| CrimsonBlaze  | Crimson Blaze    |
| FrostOrbit    | Frost Orbit      |

If a folder is missing, `BeyModelBuilder` falls back to procedural geometry.

## Creator Store mesh (optional)

In `BeyCatalog.lua`, set `modelAssets.meshId` to an `rbxassetid://…` from the Toolbox.

Search: **spinning top**, **energy ring**, or similar — use original Nova Bladers names only (no third-party IP).

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import of Storm Pegasus reference mesh as **NovaStriker**.
