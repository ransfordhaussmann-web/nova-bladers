local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	HUB_FOLDER = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Arena betreten — E drücken",
			position = Vector3.new(0, 4, 38),
			size = Vector3.new(16, 10, 8),
			color = Color3.fromRGB(255, 120, 60),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Bey auswählen — E drücken",
			position = Vector3.new(-38, 4, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Bestenliste",
			position = Vector3.new(38, 4, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 210, 80),
			action = "none",
		},
	},

	ARENA_PATHS = { "Arena.Bowl.Spawn", "Arena.Spawn" },
	LEADERBOARD_BOARD_PATH = "NovaHub.Decor.LeaderboardBoard",
}

return HubConfig
