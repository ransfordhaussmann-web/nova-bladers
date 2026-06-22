local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 0, 200),
	FLOOR_SIZE = Vector3.new(120, 1, 90),
	WALL_HEIGHT = 14,

	SPAWN = Vector3.new(0, 4, 200),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			subtitle = "Kämpfe starten",
			hint = "Betritt die Spin-Arena",
			action = "enterArena",
			position = Vector3.new(0, 2, 158),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			subtitle = "Bey wählen",
			hint = "Wähle deinen Bey",
			action = "openBeySelect",
			position = Vector3.new(-38, 2, 200),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 150, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			subtitle = "Top 5",
			hint = "Globale Bestenliste",
			action = "viewLeaderboard",
			position = Vector3.new(38, 2, 200),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn", "ArenaSpawnPoint" },
}

return HubConfig
