local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	SPAWN_POSITION = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 65),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0, -38),
			size = Vector3.new(14, 10, 6),
			color = Color3.fromRGB(255, 90, 70),
			promptText = "Arena betreten",
			action = "enterArena",
			objectText = "Arena-Tor",
		},
		BeyShop = {
			position = Vector3.new(-32, 0, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			action = "openBeySelect",
			objectText = "Bey-Shop",
		},
		StatsBoard = {
			position = Vector3.new(32, 0, 0),
			size = Vector3.new(10, 8, 4),
			color = Color3.fromRGB(70, 200, 120),
			promptText = "Statistik anzeigen",
			action = "showStats",
			objectText = "Statistik-Tafel",
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 4, 0),
	HUB_CAMERA_OFFSET = Vector3.new(0, 2, 0),
}

return HubConfig
