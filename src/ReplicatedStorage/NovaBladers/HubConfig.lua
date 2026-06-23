local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 100),
	WALL_HEIGHT = 16,
	ZONE_ACTION_KEY = Enum.KeyCode.E,
	LEADERBOARD_TOP_COUNT = 5,

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 0, 35),
			size = Vector3.new(22, 14, 10),
			color = Color3.fromRGB(255, 90, 70),
			hint = "Arena betreten",
			action = "EnterArena",
		},
		{
			id = "beylab",
			name = "Bey-Labor",
			position = Vector3.new(-38, 0, 0),
			size = Vector3.new(14, 12, 14),
			color = Color3.fromRGB(80, 160, 255),
			hint = "Bey auswählen",
			action = "OpenBeySelect",
		},
		{
			id = "hall",
			name = "Ruhmeshalle",
			position = Vector3.new(38, 0, 0),
			size = Vector3.new(14, 12, 14),
			color = Color3.fromRGB(255, 200, 60),
			hint = "Top-Spieler ansehen",
			action = "ViewLeaderboard",
		},
	},
}

return HubConfig
