local HubConfig = {
	ROOT_NAME = "NovaHub",
	SPAWN = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(96, 1, 96),
	FLOOR_COLOR = Color3.fromRGB(35, 38, 48),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONE_RADIUS = 10,
	ZONE_CHECK_INTERVAL = 0.25,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "[E] Arena betreten",
			position = Vector3.new(0, 1, 28),
			color = Color3.fromRGB(255, 120, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "[E] Bey auswählen",
			position = Vector3.new(-32, 1, 0),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(32, 1, 0),
			color = Color3.fromRGB(255, 210, 80),
			action = "none",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 6, -6),
		size = Vector3.new(14, 8, 0.5),
		face = Enum.NormalId.Front,
		topCount = 5,
	},

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
}

return HubConfig
