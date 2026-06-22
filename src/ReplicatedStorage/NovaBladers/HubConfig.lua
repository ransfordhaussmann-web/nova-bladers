local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 80),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten.",
			action = "enter_arena",
			position = Vector3.new(0, 2, 18),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 60),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen.",
			action = "open_bey_select",
			position = Vector3.new(-28, 2, -8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			action = "none",
			position = Vector3.new(28, 2, -8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(28, 6, -14),
		size = Vector2.new(10, 6),
		face = Enum.NormalId.Front,
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn", "BowlSpawn" },
	ARENA_PATHS = { "Arena", "Bowl" },
}

return HubConfig
