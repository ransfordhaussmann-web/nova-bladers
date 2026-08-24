# Bey Model Imports

Place Creator Store or custom 3D models here for in-game use.

## Studio folder

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | studioModelName | Fallback |
|-----|-----------------|----------|
| Nova Striker | NovaStriker | Procedural (Sketchfab ref in catalog) |
| Iron Shell | IronShell | Procedural heavy shell |
| Volt Dash | VoltDash | Procedural stamina ring |
| Shadow Bite | ShadowBite | Procedural dark fangs |
| Crimson Fang | CrimsonFang | Procedural ripper fangs |
| Aurora Crest | AuroraCrest | Procedural ice crystals |

## How to import

1. Roblox Studio → Toolbox → Creator Store
2. Search hint from `BeyCatalog.modelRef.creatorStoreHint`
3. Insert model, scale to ~3.5 studs wide, lay flat
4. Move under `Models/<studioModelName>`
5. Optional: set `modelAssets.meshId` in BeyCatalog for MeshPart fallback

Nova Striker GLB import: see `docs/SKETCHFAB-NOVA-STRIKER.md`
