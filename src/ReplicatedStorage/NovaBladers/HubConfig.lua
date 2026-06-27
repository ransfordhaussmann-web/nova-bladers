local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector2.new(80, 80),
	FLOOR_HEIGHT = 1,
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			position = Vector3.new(0, 0, -32),
			size = Vector3.new(14, 10, 3),
			color = Color3.fromRGB(90, 160, 255),
			promptAction = "Arena betreten",
			promptKey = Enum.KeyCode.E,
		},
		BeyShop = {
			id = "BeyShop",
			label = "Bey-Shop",
			position = Vector3.new(-28, 0, 8),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 180, 60),
			promptAction = "Bey wählen",
			promptKey = Enum.KeyCode.E,
		},
		StatsBoard = {
			id = "StatsBoard",
			label = "Ruhmeshalle",
			position = Vector3.new(28, 0, 8),
			size = Vector3.new(12, 10, 2),
			color = Color3.fromRGB(120, 220, 140),
			promptAction = "Stats anzeigen",
			promptKey = Enum.KeyCode.E,
		},
	},
}

return HubConfig
