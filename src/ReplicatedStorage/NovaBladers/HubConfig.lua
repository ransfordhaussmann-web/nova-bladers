local HubConfig = {
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_POSITION = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONE_CHECK_INTERVAL = 0.25,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Spin-Arena betreten",
			action = "enterArena",
			position = Vector3.new(0, 1, 35),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 110, 70),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "openBeySelect",
			position = Vector3.new(-38, 1, 0),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 150, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "none",
			position = Vector3.new(38, 1, 0),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 195, 50),
		},
	},

	LEADERBOARD_BOARD = {
		cframe = CFrame.new(38, 9, -10) * CFrame.Angles(0, math.rad(-90), 0),
		size = Vector3.new(14, 9, 0.4),
	},
}

return HubConfig
