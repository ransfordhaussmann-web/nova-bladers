local HubConfig = {
	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E oder betrete das Tor, um in die Arena zu gehen.",
			position = Vector3.new(0, 0, -48),
			size = Vector3.new(22, 10, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey auszuwählen.",
			position = Vector3.new(-42, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 130, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globale Top-5-Bestenliste.",
			position = Vector3.new(42, 0, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowLeaderboard",
		},
	},
}

return HubConfig
