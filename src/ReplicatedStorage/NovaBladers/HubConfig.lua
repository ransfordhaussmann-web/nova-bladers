local HubConfig = {
	SPAWN = Vector3.new(0, 4, 20),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
			promptText = "Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey!",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
			promptText = "Bey wählen",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top 5 Spieler weltweit",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(16, 10, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = nil,
			promptText = nil,
		},
	},
}

return HubConfig
