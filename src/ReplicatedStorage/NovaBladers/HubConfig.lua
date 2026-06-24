local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	HUB_FOLDER = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 60),
	WALL_HEIGHT = 12,

	ZONES = {
		Arena = {
			id = "arena",
			label = "Arena-Tor",
			hint = "Drücke E zum Betreten",
			action = "enterArena",
			position = Vector3.new(0, 1, 15),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "beylab",
			label = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			action = "openBeySelect",
			position = Vector3.new(-22, 1, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "halloffame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "viewLeaderboard",
			position = Vector3.new(22, 1, 0),
			size = Vector3.new(12, 8, 10),
			color = Color3.fromRGB(255, 210, 80),
		},
	},

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	ZONE_CHECK_INTERVAL = 0.25,
}

return HubConfig
