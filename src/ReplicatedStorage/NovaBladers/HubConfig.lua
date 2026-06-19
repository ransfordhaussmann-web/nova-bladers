local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			action = "Kampf starten",
			offset = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 12, 4),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			name = "Bey-Labor",
			action = "Bey wählen",
			offset = Vector3.new(-42, 0, 0),
			size = Vector3.new(4, 12, 18),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			action = "Stats ansehen",
			offset = Vector3.new(42, 0, 0),
			size = Vector3.new(4, 12, 18),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
