local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			actionLabel = "Arena betreten",
			action = "enter_arena",
			position = Vector3.new(0, 0.5, 38),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			signOffset = Vector3.new(0, 6, -8),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			actionLabel = "Bey auswählen",
			action = "open_bey_select",
			position = Vector3.new(42, 0.5, 0),
			size = Vector3.new(14, 1, 22),
			color = Color3.fromRGB(80, 160, 255),
			signOffset = Vector3.new(-8, 6, 0),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Arena",
			actionLabel = nil,
			action = nil,
			position = Vector3.new(-42, 0.5, 0),
			size = Vector3.new(14, 1, 22),
			color = Color3.fromRGB(255, 200, 60),
			signOffset = Vector3.new(8, 6, 0),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(-42, 8, -6),
		size = Vector2.new(10, 7),
		face = Enum.NormalId.Front,
	},

	ZONE_CHECK_INTERVAL = 0.25,
	HUB_FOLDER_NAME = "NovaHub",
}

return HubConfig
