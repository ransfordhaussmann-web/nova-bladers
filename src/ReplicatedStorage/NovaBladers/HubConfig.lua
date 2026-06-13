local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",
	HUB_SPAWN = Vector3.new(0, 4, -40),
	ARENA_SPAWN = Vector3.new(0, 6, 0),
	HUB_FLOOR_SIZE = Vector3.new(140, 1, 140),
	HUB_FLOOR_Y = 0.5,

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			promptText = "Arena betreten",
			promptAction = "EnterArena",
			label = "Arena Gate",
		},
		BeyShop = {
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			promptText = "Bey wählen",
			promptAction = "OpenBeySelect",
			label = "Bey Shop",
		},
		StatsBoard = {
			position = Vector3.new(38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Statistik ansehen",
			promptAction = "OpenStats",
			label = "Ruhmeshalle",
		},
	},
}

return HubConfig
