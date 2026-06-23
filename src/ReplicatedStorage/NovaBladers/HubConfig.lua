local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 90),
	FLOOR_CENTER = Vector3.new(0, 0, 0),

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			action = "EnterArena",
			hint = "Drücke E um die Arena zu betreten",
			center = Vector3.new(0, 2, 30),
			size = Vector3.new(18, 8, 10),
			color = Color3.fromRGB(255, 120, 60),
		},
		{
			id = "beylab",
			name = "Bey-Labor",
			action = "OpenBeySelect",
			hint = "Drücke E um deinen Bey zu wählen",
			center = Vector3.new(-32, 2, -8),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "halloffame",
			name = "Ruhmeshalle",
			action = "ShowLeaderboard",
			hint = "Top-Spieler ansehen",
			center = Vector3.new(32, 2, -8),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 210, 80),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 6, -14),
		size = Vector3.new(12, 8, 0.4),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
