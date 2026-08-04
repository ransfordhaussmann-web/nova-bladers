# Bey Model Imports

Optional Creator Store / Sketchfab meshes for in-game Beys.
Without a Studio model, procedural fallbacks are built automatically.

| Studio model name | Bey | Source |
|-------------------|-----|--------|
| `NovaStriker` | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| `BlazeQuill` | Blaze Quill | Creator Store / custom import |
| `TideAnchor` | Tide Anchor | Creator Store / custom import |

After Studio import, place models under:
`ReplicatedStorage → NovaBladers → Models → <studioModelName>`

Alternative: set `modelAssets.meshId` in `BeyCatalog.lua` with an `rbxassetid://` mesh.
