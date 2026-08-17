# Bey 3D Models (Creator Store / Studio Import)

Procedural fallbacks exist for all Beys. Optional Studio models improve visuals.

## Import path

`ReplicatedStorage → NovaBladers → Models → <ModelName>`

## Supported models

| Model name  | Bey          | Notes                                              |
|-------------|--------------|----------------------------------------------------|
| NovaStriker | Nova Striker | Sketchfab GLB — see docs/SKETCHFAB-NOVA-STRIKER.md |
| BlazeWheel  | Blaze Wheel  | Creator Store spin top                             |
| FrostVeil   | Frost Veil   | Creator Store spin top                             |

## Studio workflow

1. Toolbox → Creator Store → search "spinning top" / "spin top"
2. Insert model into `Models` folder (rename to match `studioModelName` in BeyCatalog)
3. Ensure model has a PrimaryPart or Hull for welding
4. Play — BeyModelBuilder auto-scales to ~3.5 stud diameter

Without imported models, procedural builders are used automatically.
