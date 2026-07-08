
Optional Creator Store / Sketchfab models for in-game Beys.

## Studio import

Place imported models under `ReplicatedStorage → NovaBladers → Models`:

| Studio model name | Bey |
|---|---|
| NovaStriker | Nova Striker |
| IronShell | Iron Shell |
| VoltDash | Volt Dash |
| ShadowBite | Shadow Bite |
| BlazeOrbit | Blaze Orbit |
| TitanGuard | Titan Guard |

`BeyModelBuilder` auto-clones a matching model when present; otherwise procedural geometry is used.

## Creator Store

Search Roblox Studio Toolbox → Creator Store → "spinning top" / "beyblade".
After import, rename the model to the `studioModelName` above, or set `modelAssets.meshId` in `BeyCatalog.lua`.

See `docs/SKETCHFAB-NOVA-STRIKER.md` for Nova Striker Sketchfab import.
