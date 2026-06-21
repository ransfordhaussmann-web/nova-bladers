local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betritt die Spin-Arena!",
			action = "enterArena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 12, 10),
			color = Color3.fromRGB(255, 95, 75),
			accent = Color3.fromRGB(255, 160, 120),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "openBeySelect",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(70, 150, 255),
			accent = Color3.fromRGB(120, 190, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top Spieler der Nova Liga",
			action = "showLeaderboard",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 70),
			accent = Color3.fromRGB(255, 230, 140),
		},
	},

	LEADERBOARD_BOARD = {
		size = Vector2.new(10, 7),
		offset = Vector3.new(0, 6, -6),
	},

	ZONE_CHECK_INTERVAL = 0.3,
}

return HubConfig
