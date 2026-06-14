local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",
	USE_3D_HUB = true,

	SPAWN_POSITION = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 2, -28),
			size = Vector3.new(10, 8, 3),
			color = Color3.fromRGB(220, 80, 80),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
			action = "arena",
			label = "Arena",
		},
		BeyShop = {
			position = Vector3.new(-24, 2, 0),
			size = Vector3.new(8, 8, 8),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
			action = "beySelect",
			label = "Bey Shop",
		},
		StatsBoard = {
			position = Vector3.new(24, 2, 0),
			size = Vector3.new(10, 8, 3),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Statistiken anzeigen",
			promptKey = Enum.KeyCode.E,
			action = "stats",
			label = "Ruhmeshalle",
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),
}

return HubConfig
