local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_NAME = "HubSpawn",

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONE_RADIUS = 10,
	INTERACT_DISTANCE = 14,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			subtitle = "Kampf starten",
			color = Color3.fromRGB(255, 90, 70),
			position = Vector3.new(0, 0, -42),
			action = "enterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			subtitle = "Bey auswählen",
			color = Color3.fromRGB(80, 160, 255),
			position = Vector3.new(-38, 0, 18),
			action = "openBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			subtitle = "Stats & Rangliste",
			color = Color3.fromRGB(255, 200, 60),
			position = Vector3.new(38, 0, 18),
			action = "showStats",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
