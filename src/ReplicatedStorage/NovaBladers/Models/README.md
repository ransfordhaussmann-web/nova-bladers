# Bey Models (Studio Import)

Procedural models are built at runtime by `BeyModelBuilder.lua`.
Optional Creator Store meshes can replace them per Bey.

## Studio Import (Sketchfab / Toolbox)

1. Roblox Studio → Toolbox → Creator Store
2. Search using `modelAssets.creatorStoreSearch` from `BeyCatalog.lua`
3. Insert mesh into `ReplicatedStorage → NovaBladers → Models → <BeyId>`
4. Or set `modelAssets.meshId = "rbxassetid://..."` in the catalog

## Creator Store Search Terms

| Bey | Search Term |
|-----|-------------|
| Nova Striker | Sketchfab import — see docs/SKETCHFAB-NOVA-STRIKER.md |
| Crimson Fang | `spinning top attack blade` |
| Granite Fort | `spinning top defense shield` |
| Solar Drift | `spinning top stamina ring` |
| Phantom Edge | `spinning top balance phantom` |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <ModelName>`
