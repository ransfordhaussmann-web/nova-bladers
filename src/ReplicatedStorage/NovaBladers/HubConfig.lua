local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 2, 18),
			size = Vector3.new(14, 8, 10),
			color = Color3.fromRGB(255, 120, 60),
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-24, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova-Liga",
			position = Vector3.new(24, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = nil,
		},
	},

	FLOOR_SIZE = Vector3.new(80, 1, 70),
	WALL_HEIGHT = 14,
	LEADERBOARD_REFRESH = 30,
}

return HubConfig
