# Bey Models — Studio Import Slots

Optional Creator Store / Sketchfab models for each bey. Procedural fallbacks work without imports.

| Model Name | Bey | Creator Store search |
|------------|-----|----------------------|
| `NovaStriker` | Nova Striker | beyblade attack, spinning top pegasus |
| `IronShell` | Iron Shell | beyblade defense, metal defense top |
| `VoltDash` | Volt Dash | beyblade stamina, sonic top |
| `ShadowBite` | Shadow Bite | dark spinning top, purple top |
| `CrystalVortex` | Crystal Vortex | crystal spinning top, ice beyblade |
| `EmberRing` | Ember Ring | fire spinning top, phoenix beyblade |

## Import steps (Studio)

1. **View → Toolbox → Creator Store** — search terms from `BeyCatalog.creatorStore`
2. Insert model into `ReplicatedStorage/NovaBladers/Models/<ModelName>`
3. Name the folder/model exactly as in the table above
4. Set `PrimaryPart` on the collision hull; name it `Hull` if possible
5. Play — `BeyModelBuilder` clones and scales to ~3.5 studs

## Sketchfab (Nova Striker only)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via `tools/nova-striker-import/`.

## MeshId shortcut

Alternatively set `modelAssets.meshId` in `BeyCatalog.lua` — see `docs/BEY-MODELS.md`.
