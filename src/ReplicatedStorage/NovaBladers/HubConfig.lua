local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	SPAWN_POSITION = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 65),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 4, -28),
			size = Vector3.new(10, 8, 3),
			color = Color3.fromRGB(255, 120, 80),
			prompt = "Arena betreten",
			action = "enterArena",
			holdDuration = 0,
		},
		BeyShop = {
			position = Vector3.new(-24, 4, 0),
			size = Vector3.new(8, 7, 8),
			color = Color3.fromRGB(80, 160, 255),
			prompt = "Bey wählen",
			action = "openBeySelect",
			holdDuration = 0,
		},
		StatsBoard = {
			position = Vector3.new(24, 4, 0),
			size = Vector3.new(10, 8, 2),
			color = Color3.fromRGB(200, 180, 80),
			prompt = "Statistiken anzeigen",
			action = "showStats",
			holdDuration = 0,
		},
	},
}

return HubConfig
