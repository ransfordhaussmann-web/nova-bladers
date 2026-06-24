local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3, 20),
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(80, 1, 60),
	FLOOR_POSITION = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E oder nutze das Tor, um die Arena zu betreten",
			position = Vector3.new(0, 2, -18),
			size = Vector3.new(14, 8, 10),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-22, 2, 8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Bestenliste — Top-Kämpfer der Nova Bladers",
			position = Vector3.new(22, 2, 8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(22, 5, 2),
		size = Vector3.new(10, 6, 0.5),
		face = Enum.NormalId.Front,
	},
}

return HubConfig
