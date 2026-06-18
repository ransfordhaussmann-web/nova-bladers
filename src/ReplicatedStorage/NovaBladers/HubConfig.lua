local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	SPAWN_POSITION = Vector3.new(0, 4, 15),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Kämpfe starten",
			position = Vector3.new(0, 5, -42),
			size = Vector3.new(18, 12, 10),
			color = Color3.fromRGB(255, 110, 50),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey auswählen",
			position = Vector3.new(-42, 5, 0),
			size = Vector3.new(10, 12, 18),
			color = Color3.fromRGB(80, 160, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Statistiken ansehen",
			position = Vector3.new(42, 5, 0),
			size = Vector3.new(10, 12, 18),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowStats",
		},
	},
}

return HubConfig
