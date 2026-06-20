local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,
	SPAWN_OFFSET = Vector3.new(0, 3, 20),
	INTERACT_DISTANCE = 12,

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn" },
	ARENA_FALLBACK_OFFSET = Vector3.new(0, 5, 200),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena",
			position = Vector3.new(0, 4, -48),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-46, 4, 0),
			size = Vector3.new(10, 8, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Stats & Leaderboard",
			position = Vector3.new(46, 4, 0),
			size = Vector3.new(10, 8, 14),
			color = Color3.fromRGB(255, 210, 80),
		},
	},
}

return HubConfig
