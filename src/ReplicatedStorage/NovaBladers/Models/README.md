# Bey 3D Models (Creator Store / Studio Import)

Place imported models here as child `Model` instances. `BeyModelBuilder` clones them at runtime when present; otherwise procedural fallbacks are used.

## Import in Roblox Studio

1. Toolbox → Creator Store → search the `creatorStoreQuery` from `BeyCatalog.modelRef`
2. Insert model into this folder (`ReplicatedStorage → NovaBladers → Models`)
3. Rename to the `studioModelName` from the catalog entry

| Bey | studioModelName | Creator Store Query |
|-----|-----------------|---------------------|
| Nova Striker | NovaStriker | (Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md) |
| Iron Shell | IronShell | spinning top metal |
| Volt Dash | VoltDash | spinning top yellow |
| Shadow Bite | ShadowBite | spinning top dark |
| Crimson Forge | CrimsonForge | spinning top red |
| Frost Crown | FrostCrown | spinning top ice |

## Optional: Direct Mesh ID

Set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` from a Toolbox mesh — no Studio folder import needed.
