local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 80),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 0, 30),
			size = Vector3.new(18, 12, 10),
			hint = "Betrete die Arena und kämpfe!",
			actionLabel = "Arena betreten",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			position = Vector3.new(-35, 0, 0),
			size = Vector3.new(14, 10, 14),
			hint = "Wähle deinen Bey aus.",
			actionLabel = "Bey wählen",
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(35, 0, 0),
			size = Vector3.new(14, 10, 14),
			hint = "Top-Spieler der Nova Bladers.",
			actionLabel = nil,
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn", "BowlSpawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
}

return HubConfig
