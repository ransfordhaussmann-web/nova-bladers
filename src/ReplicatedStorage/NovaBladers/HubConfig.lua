local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 2, 120),
	WALL_HEIGHT = 16,
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			position = Vector3.new(0, 2, -45),
			size = Vector3.new(20, 12, 8),
			color = Color3.fromRGB(255, 100, 80),
			hint = "Betrete die Arena!",
		},
		BeyLab = {
			name = "Bey-Labor",
			position = Vector3.new(-40, 2, 0),
			size = Vector3.new(16, 12, 16),
			color = Color3.fromRGB(80, 140, 255),
			hint = "Wähle deinen Bey!",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			position = Vector3.new(40, 2, 0),
			size = Vector3.new(16, 12, 16),
			color = Color3.fromRGB(255, 200, 60),
			hint = "Sieh die Besten!",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
