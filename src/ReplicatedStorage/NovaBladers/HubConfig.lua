local HubConfig = {
	HUB_SIZE = 96,
	FLOOR_HEIGHT = 1,
	SPAWN_Y = 4,

	PORTAL_OFFSET = 32,
	PORTAL_SIZE = Vector3.new(14, 12, 3),

	MODE_PADS = {
		Training = {
			id = "training",
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			offset = Vector3.new(-28, 0, 0),
			color = Color3.fromRGB(100, 180, 255),
		},
		PvP = {
			id = "pvp",
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			offset = Vector3.new(28, 0, 0),
			color = Color3.fromRGB(255, 140, 80),
		},
		FFA = {
			id = "ffa",
			label = "FFA",
			desc = "3+ Spieler — Free-for-All",
			offset = Vector3.new(0, 0, -28),
			color = Color3.fromRGB(180, 100, 255),
		},
	},

	LEADERBOARD_OFFSET = Vector3.new(-18, 0, 14),
	WALK_SPEED = 16,
	RETURN_SPAWN_OFFSET = Vector3.new(0, 0, -6),

	-- HubWorld zone definitions (walkable hub alternate layout)
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_POSITION = Vector3.new(0, 0.5, 0),
	SPAWN_OFFSET = Vector3.new(0, 3, -25),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E oder betrete das Tor, um zu kämpfen!",
			position = Vector3.new(0, 0.5, 30),
			size = Vector3.new(16, 8, 8),
			color = Color3.fromRGB(255, 100, 80),
			action = "arena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen.",
			position = Vector3.new(-28, 0.5, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "beyselect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top 5 Spieler der Arena.",
			position = Vector3.new(28, 0.5, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "leaderboard",
		},
	},

	ARENA_FOLDER = "Arena",
	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	LEADERBOARD_TOP = 5,
}

return HubConfig
