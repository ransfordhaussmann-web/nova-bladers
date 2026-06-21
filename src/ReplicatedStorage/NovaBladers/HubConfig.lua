local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	SPAWN_OFFSET = Vector3.new(0, 4, 25),

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(42, 48, 68),
		Trim = Color3.fromRGB(90, 140, 255),
		Arena = Color3.fromRGB(255, 120, 80),
		BeyLab = Color3.fromRGB(80, 200, 140),
		Hall = Color3.fromRGB(255, 210, 80),
	},

	ZONES = {
		{
			id = "Arena",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena und kämpfe!",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 12, 6),
			colorKey = "Arena",
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey vor dem Kampf.",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(6, 12, 18),
			colorKey = "BeyLab",
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(6, 12, 18),
			colorKey = "Hall",
			action = "HallOfFame",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(42, 6, -8),
		size = Vector3.new(10, 8, 0.5),
		maxEntries = 5,
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
}

return HubConfig
