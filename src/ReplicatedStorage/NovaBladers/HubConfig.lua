local HubConfig = {
	WORLD_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 30),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	AMBIENT = Color3.fromRGB(35, 45, 70),
	OUTDOOR_BRIGHTNESS = 2.4,

	ZONE_ACTION_KEY = Enum.KeyCode.E,
	ZONE_CHECK_INTERVAL = 0.25,
	ZONE_ENTER_RADIUS = 10,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			action = "enterArena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um dein Bey zu wählen",
			action = "openBeySelect",
			position = Vector3.new(-42, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 150, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "showLeaderboard",
			position = Vector3.new(42, 0, 18),
			size = Vector3.new(18, 14, 18),
			color = Color3.fromRGB(255, 195, 50),
		},
	},
}

return HubConfig
