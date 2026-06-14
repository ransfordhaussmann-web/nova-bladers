local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	SPAWN_POSITION = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(14, 8, 4),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
		},
		BeyShop = {
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(255, 180, 60),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
		},
		StatsBoard = {
			position = Vector3.new(38, 4, 0),
			size = Vector3.new(12, 8, 2),
			color = Color3.fromRGB(60, 200, 140),
			promptText = "Stats ansehen",
			promptKey = Enum.KeyCode.E,
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),
}

return HubConfig
