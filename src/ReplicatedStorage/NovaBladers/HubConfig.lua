local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 0),

	FLOOR = {
		size = Vector3.new(128, 1, 128),
		color = Color3.fromRGB(34, 38, 52),
		material = Enum.Material.Slate,
	},

	WALLS = {
		height = 14,
		thickness = 2,
		color = Color3.fromRGB(48, 54, 72),
		material = Enum.Material.Concrete,
	},

	SPAWN = Vector3.new(0, 4, 46),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 12, 10),
			color = Color3.fromRGB(255, 120, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-38, 0, 8),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Globales Leaderboard",
			position = Vector3.new(38, 0, 8),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 210, 70),
			action = "viewLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 6, 8),
		size = Vector3.new(14, 8, 0.4),
		face = Enum.NormalId.Front,
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },

	PROXIMITY_DISTANCE = 10,
}

return HubConfig
