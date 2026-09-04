# Bey Models — Studio Import

Place imported Creator Store / FBX models under `ReplicatedStorage/NovaBladers/Models/`.
`BeyModelBuilder` clones by `modelRef.studioModelName`; procedural layers are used as fallback.

| Bey ID | Studio model name | Special |
|--------|-------------------|---------|
| NovaStriker | NovaStriker | Nova Meteor Shower |
| IronShell | IronShell | Iron Vault Lock |
| VoltDash | VoltDash | Volt Sonic Tempest |
| ShadowBite | ShadowBite | Shadow Eclipse Fang |
| CrimsonFang | CrimsonFang | Crimson Fang Barrage |
| GraniteFort | GraniteFort | Granite Rampart |
| SolarDrift | SolarDrift | Solar Flare Loop |
| PhantomEdge | PhantomEdge | Phantom Mirage Cut |
| CrystalEdge | CrystalEdge | Crystal Shard Storm |
| BlazeCrown | BlazeCrown | Blaze Crown Nova |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` (avoid official IP names)
2. Insert model into `ReplicatedStorage/NovaBladers/Models/`
3. Rename folder to the **Studio model name** from the table above
4. Scale ~3–4 studs wide, flat on arena floor
5. Play — if no model is found, procedural fallback renders automatically

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md` (Nova Striker reference mesh)
