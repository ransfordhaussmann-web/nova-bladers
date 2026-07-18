# Bey 3D Models (Creator Store / Sketchfab)

Import models into Studio under **ReplicatedStorage → NovaBladers → Models**.

| Model name     | Bey           | Source hint                          |
|----------------|---------------|--------------------------------------|
| NovaStriker    | Nova Striker  | Sketchfab GLB (see docs)             |
| CrystalBloom   | Crystal Bloom | Creator Store → crystal spinning top |
| EmberForge     | Ember Forge   | Creator Store → fire spinning top    |

## Setup

1. Roblox Studio → Toolbox → Creator Store → search for spinning top models
2. Insert model into `Models/` folder, rename to match `studioModelName` in `BeyCatalog.lua`
3. Optional: paste `rbxassetid://…` into `modelAssets.meshId` for MeshPart fallback

Procedural builders are used automatically when no Studio model or meshId is found.
