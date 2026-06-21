local HubConfig = {
	HUB_MODEL_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 18,
	WALL_THICKNESS = 2,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betritt die Spin-Arena",
			prompt = "Arena betreten",
			action = "enter_arena",
			position = Vector3.new(0, 0, -48),
			size = Vector3.new(20, 14, 10),
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Nova Bey",
			prompt = "Bey wählen",
			action = "open_bey_select",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(16, 12, 16),
			color = Color3.fromRGB(75, 135, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Sieh die besten Kämpfer",
			prompt = "Leaderboard",
			action = "show_leaderboard",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(16, 12, 16),
			color = Color3.fromRGB(255, 210, 70),
		},
	},

	LEADERBOARD_BOARD = {
		offset = Vector3.new(0, 7, -7),
		size = Vector2.new(14, 9),
	},
}

return HubConfig
