local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_FLOOR_SIZE = Vector3.new(120, 1, 120),
	HUB_FLOOR_COLOR = Color3.fromRGB(45, 50, 65),
	HUB_SPAWN_POSITION = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			displayName = "Arena Gate",
			position = Vector3.new(0, 4, -42),
			size = Vector3.new(16, 10, 5),
			color = Color3.fromRGB(255, 95, 75),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
		},
		BeyShop = {
			displayName = "Bey Shop",
			position = Vector3.new(-38, 4, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
		},
		StatsBoard = {
			displayName = "Ruhmeshalle",
			position = Vector3.new(38, 6, 0),
			size = Vector3.new(10, 12, 3),
			color = Color3.fromRGB(255, 200, 80),
			promptText = "Stats ansehen",
			promptKey = Enum.KeyCode.E,
		},
	},
}

return HubConfig
