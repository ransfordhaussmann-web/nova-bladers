local HubConfig = {
	HUB_MODEL_NAME = "NovaHub",
	FLOOR_SIZE = Vector2.new(80, 60),
	WALL_HEIGHT = 12,
	SPAWN_POSITION = Vector3.new(0, 3, 12),

	COLORS = {
		Floor = Color3.fromRGB(35, 40, 55),
		Wall = Color3.fromRGB(50, 55, 75),
		Accent = Color3.fromRGB(100, 180, 255),
		SpawnPad = Color3.fromRGB(70, 90, 130),
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			action = "EnterArena",
			hint = "Arena betreten",
			position = Vector3.new(0, 0, -24),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			action = "OpenBeySelect",
			hint = "Bey wählen",
			position = Vector3.new(-22, 0, 8),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			action = "ShowLeaderboard",
			hint = "Bestenliste ansehen",
			position = Vector3.new(22, 0, 8),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_FOLDER_NAME = "Arena",
	ARENA_SPAWN_NAME = "ArenaSpawn",
}

return HubConfig
