local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR = {
		size = Vector3.new(120, 1, 120),
		position = Vector3.new(0, 0, 0),
		color = Color3.fromRGB(28, 32, 48),
	},

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		Arena = {
			id = "Arena",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			action = "enterArena",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(255, 95, 75),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			action = "openBeySelect",
			position = Vector3.new(-38, 1, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(70, 150, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "none",
			position = Vector3.new(38, 1, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 195, 55),
		},
	},

	ZONE_DETECT_RADIUS = 11,
	INTERACT_KEY = Enum.KeyCode.E,

	ARENA_FOLDER = "Arena",
	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FALLBACK_OFFSET = Vector3.new(0, 6, 0),

	LEADERBOARD = {
		boardSize = Vector3.new(14, 9, 0.4),
		boardOffset = Vector3.new(0, 7, -7),
		topCount = 5,
	},
}

return HubConfig
