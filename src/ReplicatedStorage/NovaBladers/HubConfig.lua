local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(40, 46, 68),
		Accent = Color3.fromRGB(90, 140, 255),
		ArenaGate = Color3.fromRGB(255, 120, 80),
		BeyLab = Color3.fromRGB(80, 200, 140),
		HallOfFame = Color3.fromRGB(255, 210, 80),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(18, 10, 6),
			colorKey = "ArenaGate",
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey aus.",
			position = Vector3.new(-38, 2, 10),
			size = Vector3.new(14, 10, 14),
			colorKey = "BeyLab",
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			position = Vector3.new(38, 2, 10),
			size = Vector3.new(14, 10, 14),
			colorKey = "HallOfFame",
			action = "ShowLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 8, 4),
		size = Vector3.new(12, 8, 0.5),
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FOLDER = "Arena",
}

return HubConfig
