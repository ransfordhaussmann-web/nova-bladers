local HubConfig = {
	SPAWN = Vector3.new(0, 4, 200),

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 0.5, 160),
			size = Vector3.new(14, 8, 14),
			action = "enterArena",
			color = Color3.fromRGB(255, 120, 60),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um dein Bey zu wählen",
			position = Vector3.new(-40, 0.5, 200),
			size = Vector3.new(14, 8, 14),
			action = "openBeySelect",
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globales Leaderboard — Top 5 Spieler",
			position = Vector3.new(40, 0.5, 200),
			size = Vector3.new(16, 8, 14),
			action = "none",
			color = Color3.fromRGB(255, 210, 80),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(40, 6, 193),
		size = Vector3.new(14, 8, 0.5),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
