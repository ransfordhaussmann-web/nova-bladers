local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_CENTER = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 120, 80),
			action = "enterArena",
			hint = "Drücke E — Arena betreten",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
			hint = "Drücke E — Bey wählen",
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 210, 80),
			action = "viewLeaderboard",
			hint = "Top-Spieler ansehen",
		},
	},

	LEADERBOARD_REFRESH = 30,
	ZONE_CHECK_INTERVAL = 0.25,
}

return HubConfig
