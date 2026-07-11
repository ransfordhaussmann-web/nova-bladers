# Creator Store / Studio Models

Optional 3D models for in-game Beys. Procedural fallbacks work without imports.

## Import (Roblox Studio)

1. Toolbox → Creator Store → search "spinning top" / "beyblade" (use only licensed assets)
2. Place model under `ReplicatedStorage → NovaBladers → Models`
3. Name must match `modelRef.studioModelName` in `BeyCatalog.lua`

| Model name   | Bey          |
|--------------|--------------|
| NovaStriker  | Nova Striker |
| IronShell    | Iron Shell   |
| VoltDash     | Volt Dash    |
| ShadowBite   | Shadow Bite  |
| FrostCrown   | Frost Crown  |
| EmberFang    | Ember Fang   |

## Alternative: meshId

Set `modelAssets.meshId` in `BeyCatalog.lua` (rbxassetid) to use a MeshPart directly without a Studio model folder.

## Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import as **NovaStriker**.
