local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_OFFSET = Vector3.new(0, 3, 40),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			description = "Betrete die Kampfarena",
			position = Vector3.new(0, 0, -35),
			size = Vector3.new(20, 12, 8),
			color = Color3.fromRGB(220, 80, 80),
			action = "EnterArena",
		},
		BeyLab = {
			name = "Bey-Labor",
			description = "Wähle deinen Bey",
			position = Vector3.new(-35, 0, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			description = "Top-Spieler ansehen",
			position = Vector3.new(35, 0, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowLeaderboard",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Arena.ArenaSpawn" },
	HUB_MODEL_NAME = "NovaHub",
	HUB_SPAWN_NAME = "HubSpawn",
}

return HubConfig
