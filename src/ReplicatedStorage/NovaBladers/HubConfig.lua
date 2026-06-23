local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	HUB_FOLDER = "NovaHub",

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 20,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 0, 35),
			size = Vector3.new(20, 12, 8),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-40, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Arena",
			position = Vector3.new(40, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = "none",
		},
	},

	ZONE_CHECK_INTERVAL = 0.2,
	LEADERBOARD_REFRESH = 30,
}

return HubConfig
