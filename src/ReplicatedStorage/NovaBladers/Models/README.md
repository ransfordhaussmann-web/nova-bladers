
Import Creator Store / Sketchfab models here for in-game use.

| Studio model name | Bey ID       | Notes |
|-------------------|--------------|-------|
| NovaStriker       | NovaStriker  | See docs/SKETCHFAB-NOVA-STRIKER.md |
| IronShell         | IronShell    | Defense bey |
| VoltDash          | VoltDash     | Stamina bey |
| ShadowBite        | ShadowBite   | Balance bey |
| CrimsonFang       | CrimsonFang  | Attack bey |
| FrostCrown        | FrostCrown   | Defense bey |

After Studio import: ReplicatedStorage → NovaBladers → Models → `<studioModelName>`

BeyModelBuilder priority: Models folder (`modelRef.studioModelName`) → `modelAssets.meshId` → procedural fallback.
