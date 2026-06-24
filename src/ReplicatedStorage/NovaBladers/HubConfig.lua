local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(80, 1, 70),
	WALL_HEIGHT = 12,

	ZONE_CHECK_INTERVAL = 0.25,
	ZONE_PROXIMITY = 9,

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			position = Vector3.new(0, 2, 25),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 60),
			action = "enterArena",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			position = Vector3.new(-22, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(22, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			action = "viewLeaderboard",
		},
	},
}

return HubConfig
