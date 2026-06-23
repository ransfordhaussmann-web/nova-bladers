local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		Arena = {
			id = "Arena",
			name = "Arena-Tor",
			position = Vector3.new(0, 1, 42),
			size = Vector3.new(22, 0.5, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "EnterArena",
			hint = "Arena betreten [E]",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-42, 1, 0),
			size = Vector3.new(16, 0.5, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
			hint = "Bey auswählen [E]",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(42, 1, 0),
			size = Vector3.new(16, 0.5, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = nil,
			hint = "Top-Spieler ansehen",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(42, 8, -6),
		size = Vector3.new(14, 10, 0.5),
		face = Enum.NormalId.Front,
	},
}

return HubConfig
