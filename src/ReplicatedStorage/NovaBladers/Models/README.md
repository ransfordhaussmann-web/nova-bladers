# Bey 3D Models (Creator Store / Studio Import)

Place imported spinning-top models here as **Model** instances. `BeyModelBuilder` clones them when present; otherwise procedural meshes are used.

## Model names (must match exactly)

| Catalog ID   | Studio model name | Bey            |
|--------------|-------------------|----------------|
| NovaStriker  | NovaStriker       | Nova Striker   |
| IronShell    | IronShell         | Iron Shell     |
| VoltDash     | VoltDash          | Volt Dash      |
| ShadowBite   | ShadowBite        | Shadow Bite    |
| CrimsonFang  | CrimsonFang       | Crimson Fang   |
| FrostCrown   | FrostCrown        | Frost Crown    |

## Import steps (Roblox Studio)

1. Toolbox → Creator Store → search **spinning top** or **beyblade** (free models)
2. Insert model into `ReplicatedStorage → NovaBladers → Models`
3. Rename to the **Studio model name** from the table above
4. Set **PrimaryPart** (or a child named `Hull`) for welding
5. Play — `BeyModelBuilder` auto-scales to ~3.5 stud diameter

### Nova Striker (Sketchfab)

See `docs/SKETCHFAB-NOVA-STRIKER.md` for GLB import via the one-click tool.
