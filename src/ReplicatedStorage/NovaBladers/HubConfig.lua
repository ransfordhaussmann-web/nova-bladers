local HubConfig = {
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_POSITION = Vector3.new(0, 3, -40),

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			position = Vector3.new(0, 0, 35),
			size = Vector3.new(20, 12, 8),
			color = Color3.fromRGB(255, 100, 80),
			actionText = "Kämpfen",
			promptHold = 0,
		},
		BeyLab = {
			name = "Bey-Labor",
			position = Vector3.new(-40, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			actionText = "Auswählen",
			promptHold = 0,
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			position = Vector3.new(40, 0, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			actionText = "Ansehen",
			promptHold = 0,
		},
	},
}

return HubConfig
