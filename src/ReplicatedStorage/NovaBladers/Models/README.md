
Optional Creator Store / imported models for in-game Bey visuals.

| Model name   | Bey          | Notes                                      |
|--------------|--------------|--------------------------------------------|
| NovaStriker  | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| CrimsonFang  | Crimson Fang | Toolbox spin-top mesh (optional)           |
| FrostHalo    | Frost Halo   | Toolbox spin-top mesh (optional)           |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<ModelName>`

Procedural fallbacks are built automatically when no model is present.
Optional `modelAssets.meshId` in BeyCatalog overrides with a rbxassetid.
