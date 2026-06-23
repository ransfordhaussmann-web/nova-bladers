local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_Y = 2,
	WALL_HEIGHT = 14,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um in die Arena zu gehen",
			action = "EnterArena",
			position = Vector3.new(0, 5, 35),
			size = Vector3.new(18, 10, 12),
			color = Color3.fromRGB(255, 90, 70),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "OpenBeySelect",
			position = Vector3.new(-38, 5, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers",
			action = nil,
			position = Vector3.new(38, 5, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "BowlSpawn" },
	ARENA_PATHS = {
		{ "Arena", "Bowl", "Spawn" },
		{ "Arena", "Spawn" },
	},

	LEADERBOARD_BOARD_SIZE = Vector2.new(800, 500),
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
