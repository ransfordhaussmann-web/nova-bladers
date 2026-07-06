# Bey Models (Studio Import)

Optional Creator Store / Sketchfab models for in-game use.

After Studio import, place models under:
`ReplicatedStorage → NovaBladers → Models`

| Studio model name | Bey |
|-------------------|-----|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| CrimsonBlaze | Crimson Blaze |
| FrostOrbit | Frost Orbit |

## Creator Store meshId (no Studio model file)

In `BeyCatalog.lua`, set `modelAssets.meshId` on a bey entry:

```lua
modelAssets = {
    meshId = "rbxassetid://YOUR_ID",
    size = Vector3.new(3.6, 1.2, 3.6),
},
```

Procedural layers are skipped when a Studio model or `meshId` is present.

See also: `docs/BEY-MODELS.md`, `docs/SKETCHFAB-NOVA-STRIKER.md`
