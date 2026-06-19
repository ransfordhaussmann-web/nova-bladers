local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_FLOOR_SIZE = Vector3.new(120, 1, 120),
	HUB_FLOOR_POSITION = Vector3.new(0, 0, 0),
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			position = Vector3.new(0, 2, -48),
			size = Vector3.new(14, 8, 4),
			color = Color3.fromRGB(255, 90, 70),
			promptAction = "EnterArena",
			promptText = "Arena betreten",
			holdDuration = 0,
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			position = Vector3.new(-42, 2, 10),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			promptAction = "OpenBeySelect",
			promptText = "Bey wählen",
			holdDuration = 0,
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			position = Vector3.new(42, 2, 10),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			promptAction = "ShowStats",
			promptText = "Statistiken ansehen",
			holdDuration = 0,
		},
	},
}

return HubConfig
