local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 18,
	SPAWN_POSITION = Vector3.new(0, 3, 20),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			description = "Betritt die Spin-Arena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 14, 10),
			color = Color3.fromRGB(60, 120, 255),
			glowColor = Color3.fromRGB(100, 180, 255),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			description = "Wähle deinen Bey",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(14, 12, 14),
			color = Color3.fromRGB(200, 160, 40),
			glowColor = Color3.fromRGB(255, 220, 80),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			description = "Top-Spieler ansehen",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(14, 12, 14),
			color = Color3.fromRGB(120, 60, 200),
			glowColor = Color3.fromRGB(180, 100, 255),
			action = "ShowStats",
		},
	},
}

return HubConfig
