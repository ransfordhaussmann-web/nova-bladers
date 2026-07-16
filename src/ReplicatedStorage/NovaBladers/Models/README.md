# Bey Model Slots

Optional Creator Store / imported 3D models. Place each model under:

`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

| Bey | Studio folder | Creator Store search (see BeyCatalog.creatorStore) |
|-----|---------------|-----------------------------------------------------|
| Nova Striker | `NovaStriker` | beyblade attack, spinning top pegasus |
| Iron Shell | `IronShell` | beyblade defense, metal shell |
| Volt Dash | `VoltDash` | beyblade stamina, sonic ring |
| Shadow Bite | `ShadowBite` | beyblade balance, shadow fang |
| Crystal Vortex | `CrystalVortex` | crystal spinning top, gem vortex |
| Ember Ring | `EmberRing` | fire spinning top, ember ring |

If no model is present, `BeyModelBuilder` builds a procedural layered mesh at runtime.

**Nova Striker** also has a Sketchfab reference — see `docs/SKETCHFAB-NOVA-STRIKER.md`.

**Import steps (Studio):**

1. Toolbox → Creator Store → search terms from `BeyCatalog.creatorStore`
2. Insert model, scale ~3.5 studs wide, lay flat
3. Move to `Models/<studioModelName>`, set `PrimaryPart` / `Hull`
4. Play — `tryCloneStudioModel` auto-fits and welds to the physics hull
