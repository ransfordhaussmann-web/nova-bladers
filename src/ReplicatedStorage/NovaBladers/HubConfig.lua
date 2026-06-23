local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	HUB_SIZE = Vector3.new(120, 1, 100),
	WALL_HEIGHT = 16,

	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),
	WALL_COLOR = Color3.fromRGB(50, 55, 75),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			position = Vector3.new(0, 2, 30),
			size = Vector3.new(18, 8, 6),
			color = Color3.fromRGB(220, 80, 80),
			action = "enterArena",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-35, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(80, 180, 120),
			action = "openBeySelect",
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(35, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "viewLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(35, 6, -4),
		size = Vector3.new(10, 6, 0.4),
	},
}

return HubConfig
