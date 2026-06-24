local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 100),
	WALL_HEIGHT = 16,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(18, 22, 36),
		Accent = Color3.fromRGB(80, 140, 255),
		Arena = Color3.fromRGB(255, 90, 70),
		BeyLab = Color3.fromRGB(90, 200, 140),
		Hall = Color3.fromRGB(255, 200, 80),
	},

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(18, 8, 6),
			colorKey = "Arena",
			hint = "Drücke [E] um in die Arena zu gehen",
			action = "enterArena",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			position = Vector3.new(-38, 2, -10),
			size = Vector3.new(14, 8, 14),
			colorKey = "BeyLab",
			hint = "Drücke [E] um deinen Bey zu wählen",
			action = "openBeySelect",
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(38, 2, -10),
			size = Vector3.new(14, 8, 14),
			colorKey = "Hall",
			hint = "Top-Spieler der Nova Bladers",
			action = nil,
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 6, -18),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Front,
		topCount = 5,
	},
}

return HubConfig
