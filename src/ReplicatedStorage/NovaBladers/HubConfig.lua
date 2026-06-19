local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 2, -32),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(32, 2, 0),
			size = Vector3.new(6, 8, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Deine Stats & Top-Spieler",
			position = Vector3.new(-32, 2, 0),
			size = Vector3.new(6, 8, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showStats",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
