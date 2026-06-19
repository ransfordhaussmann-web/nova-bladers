local HubConfig = {
	SPAWN = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(18, 12, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			promptText = "Arena betreten",
		},
		BeyLab = {
			name = "Bey-Labor",
			position = Vector3.new(-38, 1, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
			promptText = "Bey wählen",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			position = Vector3.new(38, 1, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showStats",
			promptText = "Statistiken ansehen",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
