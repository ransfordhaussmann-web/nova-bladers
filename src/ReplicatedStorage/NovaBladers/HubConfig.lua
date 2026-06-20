local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0.5, -48),
			radius = 9,
			label = "Arena-Tor",
			prompt = "Arena betreten",
			action = "enterArena",
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			position = Vector3.new(-42, 0.5, 18),
			radius = 8,
			label = "Bey-Labor",
			prompt = "Bey wählen",
			action = "openBeySelect",
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			position = Vector3.new(42, 0.5, 18),
			radius = 8,
			label = "Ruhmeshalle",
			prompt = "Statistiken ansehen",
			action = "showHall",
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
