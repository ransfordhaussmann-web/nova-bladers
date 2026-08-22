# Nova Bladers — Studio Model Slots

Optional Creator Store / imported models. Place each model under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| studioModelName | Bey | Creator Store search (`creatorStoreQuery`) |
|-----------------|-----|---------------------------------------------|
| NovaStriker | Nova Striker | spinning top attack blue |
| IronShell | Iron Shell | spinning top defense metal shell |
| VoltDash | Volt Dash | spinning top yellow lightning stamina |
| ShadowBite | Shadow Bite | spinning top dark purple balance |
| CrimsonForge | Crimson Forge | spinning top red fire attack |
| FrostCrown | Frost Crown | spinning top ice frost defense |

## Import steps (Studio)

1. Toolbox → Creator Store → search the query from `BeyCatalog.lua`
2. Insert model into `ReplicatedStorage/NovaBladers/Models/<studioModelName>`
3. Set `PrimaryPart` (or name collision part `Hull`), weld parts
4. Play — `BeyModelBuilder` clones the model when present; otherwise procedural layers are used
