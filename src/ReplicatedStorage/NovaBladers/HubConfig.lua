local HubConfig = {
	HUB_FOLDER = "NovaHub",
	ARENA_FOLDER = "Arena",
	ARENA_SPAWN_NAME = "ArenaSpawn",

	FLOOR_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 14,
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(42, 48, 68),
		Accent = Color3.fromRGB(90, 160, 255),
		ArenaGate = Color3.fromRGB(255, 120, 80),
		BeyLab = Color3.fromRGB(80, 220, 140),
		HallOfFame = Color3.fromRGB(255, 210, 70),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betreten, um in die Arena zu gehen",
			action = "enterArena",
			position = Vector3.new(0, 1, -34),
			size = Vector3.new(18, 1, 14),
			colorKey = "ArenaGate",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "E — Bey auswählen",
			action = "openBeySelect",
			position = Vector3.new(-34, 1, 0),
			size = Vector3.new(14, 1, 18),
			colorKey = "BeyLab",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "E — Stats & Leaderboard",
			action = "showHall",
			position = Vector3.new(34, 1, 0),
			size = Vector3.new(14, 1, 18),
			colorKey = "HallOfFame",
		},
	},

	INTERACT_DISTANCE = 10,
	ZONE_CHECK_INTERVAL = 0.35,
}

return HubConfig
