local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(140, 1, 140),
	SPAWN_OFFSET = Vector3.new(0, 4, -20),

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 0, 42),
			size = Vector3.new(18, 1, 10),
			color = Color3.fromRGB(80, 140, 255),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-38, 0, 10),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(38, 0, 10),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(200, 160, 80),
			action = "showStats",
		},
	},

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	PROXIMITY_RADIUS = 9,
}

return HubConfig
