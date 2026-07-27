# Bey Models — Studio Import

Import Creator Store or custom 3D models here. Each bey uses `modelRef.studioModelName` from `BeyCatalog.lua`.

| Model folder | Bey |
|--------------|-----|
| NovaStriker | Nova Striker (see docs/SKETCHFAB-NOVA-STRIKER.md) |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| FrostPrism | Frost Prism |
| EmberCore | Ember Core |

After Studio import: `ReplicatedStorage → NovaBladers → Models → <Name>`

If no model is present, `BeyModelBuilder` builds a procedural fallback at runtime.
