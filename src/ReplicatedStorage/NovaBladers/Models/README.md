# Bey Models (Creator Store / Studio Import)

Import spinning-top models from Roblox Creator Store or Sketchfab into Studio under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey ID | studioModelName | Notes |
|--------|-----------------|-------|
| NovaStriker | NovaStriker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell | IronShell | Creator Store or custom mesh |
| VoltDash | VoltDash | Creator Store or custom mesh |
| ShadowBite | ShadowBite | Creator Store or custom mesh |
| CrimsonFang | CrimsonFang | Optional — procedural fallback built-in |
| FrostCrown | FrostCrown | Optional — procedural fallback built-in |

## Loading priority (`BeyModelBuilder`)

1. **Models/** folder clone (`modelRef.studioModelName`)
2. **modelAssets.meshId** (Toolbox rbxassetid in `BeyCatalog`)
3. **Procedural** builder per Bey ID

If no Studio model exists, the game uses procedural 3D visuals automatically.
