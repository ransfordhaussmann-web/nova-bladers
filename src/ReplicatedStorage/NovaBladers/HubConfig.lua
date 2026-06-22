local HubConfig = {
	SPAWN = Vector3.new(0, 4, 120),
	ARENA_FALLBACK = Vector3.new(0, 6, 0),

	FLOOR_SIZE = Vector3.new(200, 2, 200),
	FLOOR_CENTER = Vector3.new(0, 1, 60),

	WALL_HEIGHT = 24,
	WALL_THICKNESS = 4,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betreten zum Kampf",
			position = Vector3.new(0, 3, 20),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey auswählen",
			position = Vector3.new(-40, 3, 55),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(40, 3, 55),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(40, 14, 72),
		size = Vector3.new(14, 10, 1),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
