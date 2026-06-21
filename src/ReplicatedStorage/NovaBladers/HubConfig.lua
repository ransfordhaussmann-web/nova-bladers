local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONE_HINT_RANGE = 14,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "enter_arena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "open_bey_select",
			position = Vector3.new(-38, 0, 10),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 180, 60),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "show_leaderboard",
			position = Vector3.new(38, 0, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(200, 160, 80),
		},
	},

	LEADERBOARD_BOARD_SIZE = Vector3.new(12, 8, 0.5),
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
