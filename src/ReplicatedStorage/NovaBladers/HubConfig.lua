local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONE_CHECK_INTERVAL = 0.25,
	ZONE_HINT_COOLDOWN = 1.5,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			color = Color3.fromRGB(255, 90, 70),
			position = Vector3.new(0, 0.5, -42),
			size = Vector3.new(18, 1, 14),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey aus.",
			color = Color3.fromRGB(80, 160, 255),
			position = Vector3.new(-42, 0.5, 0),
			size = Vector3.new(14, 1, 18),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			color = Color3.fromRGB(255, 200, 60),
			position = Vector3.new(42, 0.5, 0),
			size = Vector3.new(14, 1, 18),
			action = "showLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(42, 6, -6),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Back,
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
}

return HubConfig
