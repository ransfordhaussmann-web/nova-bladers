local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_SPAWN = CFrame.new(0, 5, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 70),

	ZONES = {
		ArenaGate = {
			label = "Arena",
			position = Vector3.new(0, 4, -42),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			promptText = "Betreten",
			action = "enterArena",
		},
		BeyShop = {
			label = "Bey Shop",
			position = Vector3.new(-34, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Auswählen",
			action = "openBeySelect",
		},
		StatsBoard = {
			label = "Statistiken",
			position = Vector3.new(34, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Ansehen",
			action = "showStats",
		},
	},
}

return HubConfig
