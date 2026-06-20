local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	COLORS = {
		Floor = Color3.fromRGB(35, 40, 55),
		Wall = Color3.fromRGB(50, 55, 75),
		Accent = Color3.fromRGB(80, 140, 255),
		ArenaGate = Color3.fromRGB(255, 90, 70),
		BeyLab = Color3.fromRGB(90, 200, 140),
		HallOfFame = Color3.fromRGB(255, 200, 60),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			position = Vector3.new(0, 1, -45),
			size = Vector3.new(18, 10, 6),
			colorKey = "ArenaGate",
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey aus.",
			position = Vector3.new(-42, 1, 0),
			size = Vector3.new(14, 10, 14),
			colorKey = "BeyLab",
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler und deine Stats.",
			position = Vector3.new(42, 1, 0),
			size = Vector3.new(14, 10, 14),
			colorKey = "HallOfFame",
			action = "ShowStats",
		},
	},

	LEADERBOARD = {
		position = Vector3.new(42, 8, -8),
		size = Vector3.new(12, 8, 0.5),
		topCount = 5,
	},
}

return HubConfig
