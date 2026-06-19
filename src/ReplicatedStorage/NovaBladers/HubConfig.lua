local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 25),

	FLOOR = {
		size = Vector3.new(120, 1, 120),
		color = Color3.fromRGB(42, 46, 58),
		material = Enum.Material.Slate,
	},

	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			prompt = "Arena betreten",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(16, 10, 8),
			color = Color3.fromRGB(220, 90, 70),
			lightColor = Color3.fromRGB(255, 140, 100),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			prompt = "Bey wählen",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(10, 10, 14),
			color = Color3.fromRGB(70, 140, 220),
			lightColor = Color3.fromRGB(120, 180, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			prompt = "Statistiken ansehen",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(10, 10, 14),
			color = Color3.fromRGB(220, 180, 60),
			lightColor = Color3.fromRGB(255, 220, 120),
		},
	},

	ARENA_SPAWN_PATHS = {
		{ "Arena", "ArenaSpawn" },
		{ "ArenaSpawn" },
	},
}

return HubConfig
