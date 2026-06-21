local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_Y = 0,
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 4, 8),

	COLORS = {
		Floor = Color3.fromRGB(35, 40, 55),
		Wall = Color3.fromRGB(50, 55, 75),
		Trim = Color3.fromRGB(80, 140, 255),
		ArenaGate = Color3.fromRGB(255, 100, 80),
		BeyLab = Color3.fromRGB(80, 200, 140),
		HallOfFame = Color3.fromRGB(255, 210, 60),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena!",
			action = "enterArena",
			position = Vector3.new(0, 1, -48),
			size = Vector3.new(18, 10, 4),
			colorKey = "ArenaGate",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey!",
			action = "openBeySelect",
			position = Vector3.new(48, 1, 0),
			size = Vector3.new(4, 10, 18),
			colorKey = "BeyLab",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "hallOfFame",
			position = Vector3.new(-48, 1, 0),
			size = Vector3.new(4, 10, 18),
			colorKey = "HallOfFame",
		},
	},

	LEADERBOARD = {
		partSize = Vector3.new(12, 8, 0.4),
		offset = Vector3.new(-48, 7, 0),
	},
}

return HubConfig
