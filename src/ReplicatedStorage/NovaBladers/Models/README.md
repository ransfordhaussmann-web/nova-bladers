# Creator Store / Imported Bey Models

Place imported models here for in-game use. Procedural fallbacks exist if a model is missing.

| Studio folder name | Bey | Creator Store search terms |
|--------------------|-----|---------------------------|
| `NovaStriker` | Nova Striker | spinning top, bey blade metal, attack bey |
| `IronShell` | Iron Shell | defense bey, spinning top shield |
| `VoltDash` | Volt Dash | stamina bey, spinning top yellow |
| `ShadowBite` | Shadow Bite | balance bey, dark spinning top |
| `CrimsonOrbit` | Crimson Orbit | red spinning top, fire bey |
| `FrostAnchor` | Frost Anchor | ice spinning top, frost bey |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** — search using terms from `BeyCatalog.modelRef.searchTerms`
2. Insert model into Workspace, scale to ~3.5 studs wide, lay flat
3. Move to `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set **PrimaryPart** (or child named `Hull`)
5. Play — `BeyModelBuilder` auto-clones instead of procedural mesh

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart.

See also `docs/BEY-MODELS.md` and `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker GLB).
