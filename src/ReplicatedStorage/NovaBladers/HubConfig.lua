local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),

	ARENA_PATHS = {
		{ "Arena", "Bowl", "Spawn" },
		{ "Arena", "Spawn" },
	},

	FLOOR_SIZE = Vector3.new(80, 1, 60),
	WALL_HEIGHT = 12,
	ZONE_CHECK_INTERVAL = 0.15,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 2, 18),
			size = Vector3.new(12, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
			action = "enter_arena",
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-22, 2, 0),
			size = Vector3.new(8, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			action = "open_bey_select",
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers",
			position = Vector3.new(22, 2, 0),
			size = Vector3.new(8, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			action = "view_leaderboard",
		},
	},

	LEADERBOARD_BOARD_SIZE = Vector2.new(420, 320),
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
