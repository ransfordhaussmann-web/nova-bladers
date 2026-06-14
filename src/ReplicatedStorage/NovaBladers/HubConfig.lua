local HubConfig = {
	HUB_FOLDER = "NovaHub",
	ARENA_FOLDER = "Arena",

	HUB_ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 65),

	SPAWN = Vector3.new(0, 4, 0),

	ZONES = {
		Arena = {
			name = "Arena Gate",
			action = "EnterArena",
			position = Vector3.new(42, 2, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(220, 90, 70),
			promptText = "Arena betreten",
			holdDuration = 0,
		},
		BeySelect = {
			name = "Bey Forge",
			action = "OpenBeySelect",
			position = Vector3.new(-42, 2, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			holdDuration = 0,
		},
		Leaderboard = {
			name = "Hall of Fame",
			action = "RefreshLeaderboard",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Rangliste ansehen",
			holdDuration = 0,
		},
	},

	LEADERBOARD_BOARD_SIZE = Vector2.new(420, 280),
	USE_3D_HUB = true,
}

return HubConfig
