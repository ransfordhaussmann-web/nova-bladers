local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 200),
	FLOOR_SIZE = Vector2.new(88, 88),
	WALL_HEIGHT = 14,
	SPAWN_OFFSET = Vector3.new(0, 4, 28),

	ARENA_SPAWN_PATHS = {
		{ "Arena", "ArenaSpawn" },
		{ "ArenaSpawn" },
	},

	ZONES = {
		ArenaGate = {
			displayName = "Arena-Tor",
			offset = Vector3.new(0, 0, -32),
			size = Vector3.new(18, 12, 10),
			color = Color3.fromRGB(255, 95, 75),
			prompt = "Arena betreten",
			action = "EnterArena",
		},
		BeyLab = {
			displayName = "Bey-Labor",
			offset = Vector3.new(-30, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 150, 255),
			prompt = "Bey wählen",
			action = "OpenBeySelect",
		},
		HallOfFame = {
			displayName = "Ruhmeshalle",
			offset = Vector3.new(30, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			prompt = "Statistiken ansehen",
			action = "ViewStats",
		},
	},
}

return HubConfig
