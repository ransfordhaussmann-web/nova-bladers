# Creator Store Bey Models

Import spinning-top models from Roblox Studio Toolbox → Creator Store into this folder.

## Per-Bey setup

| Studio model name | Creator Store search (`modelRef.creatorStoreQuery`) |
|-------------------|-----------------------------------------------------|
| NovaStriker       | spinning top attack blue                            |
| IronShell         | spinning top defense green                          |
| VoltDash          | spinning top yellow stamina                         |
| ShadowBite        | spinning top purple balance                         |
| BlazeOrbit        | spinning top fire orange                            |
| FrostCrown        | spinning top ice crystal                            |

1. Open Toolbox → Creator Store, search the query from `BeyCatalog.modelRef`.
2. Insert the model into `ReplicatedStorage → NovaBladers → Models`.
3. Rename it to the `studioModelName` (e.g. `BlazeOrbit`).
4. Play — `BeyModelBuilder` auto-scales and welds it to the physics hull.

Without an imported model, each Bey falls back to its procedural 3D builder.
