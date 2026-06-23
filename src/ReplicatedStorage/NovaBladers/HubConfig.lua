local HubConfig = {
	HUB_FOLDER = "NovaHub",
	SPAWN = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_Y = 2,
	WALL_HEIGHT = 14,

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	ARENA_FALLBACK = Vector3.new(0, 6, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enterArena",
			position = Vector3.new(0, 3.5, 15),
			size = Vector3.new(20, 10, 12),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			action = "openBeySelect",
			position = Vector3.new(-35, 3.5, -10),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "viewLeaderboard",
			position = Vector3.new(35, 3.5, -10),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
