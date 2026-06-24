local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 18,
	WALL_THICKNESS = 2,

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "BowlSpawn" },

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			position = Vector3.new(0, 0.5, 42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 110, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			position = Vector3.new(-38, 0.5, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(70, 150, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler auf dem Board",
			position = Vector3.new(38, 0.5, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(255, 200, 50),
			action = "viewLeaderboard",
		},
	},
}

return HubConfig
