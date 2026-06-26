local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 8),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 12,
	THEME = {
		Floor = Color3.fromRGB(28, 32, 52),
		Accent = Color3.fromRGB(90, 160, 255),
		Glow = Color3.fromRGB(140, 200, 255),
		Trim = Color3.fromRGB(50, 58, 90),
	},
	ZONES = {
		ArenaPortal = {
			name = "Arena-Portal",
			position = Vector3.new(0, 2, -28),
			promptText = "Arena betreten",
			promptKey = "E",
		},
		BeySelect = {
			name = "Bey-Auswahl",
			position = Vector3.new(-22, 2, -4),
			promptText = "Bey wählen",
			promptKey = "E",
		},
		Leaderboard = {
			name = "Rangliste",
			position = Vector3.new(22, 2, -4),
			boardSize = Vector2.new(320, 220),
		},
		Stats = {
			name = "Deine Stats",
			position = Vector3.new(0, 2, 18),
			boardSize = Vector2.new(280, 140),
		},
	},
	PROXIMITY = {
		MaxActivationDistance = 10,
		HoldDuration = 0,
	},
}

return HubConfig
