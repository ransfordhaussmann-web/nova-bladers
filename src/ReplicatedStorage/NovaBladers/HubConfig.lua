local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 10),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 0.5, -42),
			size = Vector3.new(22, 1, 18),
			color = Color3.fromRGB(255, 95, 75),
			hint = "E — Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-42, 0.5, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(75, 135, 255),
			hint = "E — Bey wählen",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(42, 0.5, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 195, 55),
			hint = "E — Stats & Rangliste",
		},
	},

	ARENA_SPAWN_PATHS = {
		"ArenaSpawn",
		"Arena.ArenaSpawn",
	},
	HUB_RETURN_OFFSET = Vector3.new(0, 4, 10),
	INTERACT_RANGE = 14,
}

return HubConfig
