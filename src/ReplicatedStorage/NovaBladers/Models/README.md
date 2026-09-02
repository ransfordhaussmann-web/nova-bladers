# Bey Models — Studio Import

Procedural 3D models are built at runtime. Optional Creator Store meshes can replace them.

## Import path (Studio)

After importing a mesh from Toolbox or FBX:

```
ReplicatedStorage → NovaBladers → Models → <studioModelName>
```

| Bey | studioModelName | Toolbox search hint |
|-----|-----------------|---------------------|
| Nova Striker | NovaStriker | See docs/SKETCHFAB-NOVA-STRIKER.md |
| Crimson Fang | CrimsonFang | spinning top red attack |
| Granite Fort | GraniteFort | spinning top defense heavy |
| Solar Drift | SolarDrift | spinning top yellow stamina |
| Phantom Edge | PhantomEdge | spinning top blue balance |

## Setup checklist

1. Insert model into `Models/<studioModelName>`
2. Set `PrimaryPart` (or name collision part `Hull`)
3. Scale to ~3.5 studs wide (auto-scaled at runtime if needed)
4. Lay flat — `importRotation` in BeyCatalog handles upright imports

When a Studio model exists, `BeyModelBuilder` clones it instead of the procedural mesh.
