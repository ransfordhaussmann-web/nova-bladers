local HubConfig = {
	ROOT_NAME = "NovaHub",

	SPAWN_OFFSET = Vector3.new(0, 4, 20),
	FLOOR_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	THEME = {
		Floor = Color3.fromRGB(35, 38, 48),
		Wall = Color3.fromRGB(55, 58, 72),
		Accent = Color3.fromRGB(120, 200, 255),
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E oder betrete das Tor, um zu kämpfen!",
			position = Vector3.new(0, 0, -34),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 95, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle hier deinen Bey aus!",
			position = Vector3.new(-32, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Die besten Nova Bladers aller Zeiten.",
			position = Vector3.new(32, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
		},
	},
}

return HubConfig
