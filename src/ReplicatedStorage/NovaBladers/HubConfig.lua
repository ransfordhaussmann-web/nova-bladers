local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(100, 1, 80),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			action = "enterArena",
			position = Vector3.new(0, 2, 28),
			size = Vector3.new(14, 6, 6),
			color = Color3.fromRGB(255, 120, 80),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "openBeySelect",
			position = Vector3.new(-32, 2, 0),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Top-Spieler",
			action = "showLeaderboard",
			position = Vector3.new(32, 2, 0),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(255, 210, 60),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 8, -8),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Front,
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "BowlSpawn" },
}

return HubConfig
