# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store.

Search terms are defined per Bey in `BeyCatalog.lua` (`modelRef.creatorStoreQuery`).

After import, place models here:

```
ReplicatedStorage → NovaBladers → Models → <studioModelName>
```

| Bey | studioModelName | Creator Store Query |
|-----|-----------------|---------------------|
| Nova Striker | NovaStriker | spinning top attack blue |
| Iron Shell | IronShell | spinning top defense green |
| Volt Dash | VoltDash | spinning top electric yellow |
| Shadow Bite | ShadowBite | spinning top dark purple |
| Crimson Forge | CrimsonForge | spinning top fire red |
| Frost Crown | FrostCrown | spinning top ice crystal |

If no Studio model is present, `BeyModelBuilder` falls back to procedural visuals.
