local HubConfig = {
	FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 10,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			position = Vector3.new(0, 0.5, -28),
			size = Vector3.new(14, 1, 10),
			color = Color3.fromRGB(255, 120, 80),
			prompt = "Arena betreten",
			action = "EnterArena",
		},
		BeyLab = {
			name = "Bey-Labor",
			position = Vector3.new(-26, 0.5, 0),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(80, 160, 255),
			prompt = "Bey wählen",
			action = "OpenBeySelect",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			position = Vector3.new(26, 0.5, 0),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(255, 210, 60),
			prompt = "Statistiken ansehen",
			action = "ShowHallOfFame",
		},
	},
}

return HubConfig
