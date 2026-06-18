local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 0, -30),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
			action = "EnterArena",
			prompt = "Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-28, 0, 10),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
			prompt = "Bey wählen",
		},
		FameHall = {
			id = "FameHall",
			name = "Ruhmeshalle",
			position = Vector3.new(28, 0, 10),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowStats",
			prompt = "Stats ansehen",
		},
	},

	ARENA_FOLDER_NAME = "Arena",
	ARENA_SPAWN_NAME = "ArenaSpawn",
}

return HubConfig
