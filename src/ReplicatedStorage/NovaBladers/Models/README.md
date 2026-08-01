# Nova Bladers — Studio Model Import

Place imported Creator Store / Sketchfab models here as **Models** matching `studioModelName` in `BeyCatalog.lua`.

| Bey ID | Studio model name | Notes |
|--------|-------------------|-------|
| NovaStriker | `NovaStriker` | See `docs/SKETCHFAB-NOVA-STRIKER.md` |
| IronShell | `IronShell` | Heavy defense shell |
| VoltDash | `VoltDash` | Flat stamina ring |
| ShadowBite | `ShadowBite` | Dark balance fangs |
| CrimsonFang | `CrimsonFang` | Attack rip fangs |
| FrostRing | `FrostRing` | Ice defense ring |

## Import steps (Studio)

1. Toolbox → Creator Store → search `spinning top` / `bey blade metal`
2. Insert model into Workspace, scale to ~3.5 studs wide
3. Move under `ReplicatedStorage → NovaBladers → Models → <studioModelName>`
4. Set `PrimaryPart` or name collision part `Hull`
5. Rojo sync — procedural fallback builds if model missing

Optional: set `modelAssets.meshId` in `BeyCatalog.lua` for a single MeshPart instead of a full model folder.
