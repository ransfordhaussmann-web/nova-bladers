local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_CENTER = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 2, 45),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 120, 60),
			action = "enterArena",
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			position = Vector3.new(-35, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(35, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 210, 80),
			action = "hallOfFame",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "BowlSpawn", "Spawn" },
	HUB_FOLDER_NAME = "NovaHub",
	LEADERBOARD_REFRESH = 30,
}

return HubConfig
