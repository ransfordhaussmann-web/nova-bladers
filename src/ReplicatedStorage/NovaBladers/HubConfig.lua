local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			action = "enterArena",
			position = Vector3.new(0, 1, 18),
			size = Vector3.new(14, 1, 8),
			color = Color3.fromRGB(80, 140, 255),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "openBeySelect",
			position = Vector3.new(-24, 1, -8),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Bestenliste",
			action = "viewLeaderboard",
			position = Vector3.new(24, 1, -8),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(140, 80, 220),
		},
	},

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	ZONE_CHECK_INTERVAL = 0.25,
}

return HubConfig
