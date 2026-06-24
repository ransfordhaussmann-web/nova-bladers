local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	HUB_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(80, 1, 60),
	FLOOR_POSITION = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Spin-Arena betreten",
			action = "EnterArena",
			position = Vector3.new(0, 2, 22),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			action = "OpenBeySelect",
			position = Vector3.new(-24, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			action = "ShowLeaderboard",
			position = Vector3.new(24, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
