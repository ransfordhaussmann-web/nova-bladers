local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			prompt = "Arena betreten",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-42, 1, 10),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
			prompt = "Bey wählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(42, 1, 10),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(255, 210, 80),
			action = "showHall",
			prompt = "Statistiken ansehen",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn" },
	ARENA_FOLDER = "Arena",
}

return HubConfig
