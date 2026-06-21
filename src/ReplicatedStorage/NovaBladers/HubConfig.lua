local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 35),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena — drücke [E]",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 10, 18),
			color = Color3.fromRGB(255, 95, 75),
			action = "arena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey — drücke [E]",
			position = Vector3.new(-38, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(75, 135, 255),
			action = "beySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Top-Spieler",
			position = Vector3.new(38, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 195, 55),
			action = "leaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		size = Vector3.new(14, 8, 0.4),
		offset = Vector3.new(0, 5, -6),
	},
}

return HubConfig
