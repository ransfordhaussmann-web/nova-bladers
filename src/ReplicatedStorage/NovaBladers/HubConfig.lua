local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 10,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(-22, 0, 0),
			size = Vector3.new(14, 1, 14),
			hint = "[E] Arena betreten",
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(0, 0, -22),
			size = Vector3.new(14, 1, 14),
			hint = "[E] Bey auswählen",
			color = Color3.fromRGB(70, 130, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(22, 0, 0),
			size = Vector3.new(14, 1, 14),
			hint = "Top-Spieler — siehe Tafel",
			color = Color3.fromRGB(255, 195, 50),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(22, 7, -6),
		size = Vector3.new(12, 9, 0.4),
		face = Enum.NormalId.Front,
	},

	INTERACT_DISTANCE = 10,
	HINT_FADE_TIME = 0.15,
}

return HubConfig
