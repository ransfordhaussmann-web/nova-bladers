local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_SIZE = Vector3.new(80, 1, 80),
	HUB_CENTER = Vector3.new(0, 0.5, 0),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			name = "ArenaGate",
			position = Vector3.new(-28, 2, 0),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(255, 90, 70),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
		},
		BeyShop = {
			name = "BeyShop",
			position = Vector3.new(28, 2, 0),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(80, 160, 255),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
		},
		StatsBoard = {
			name = "StatsBoard",
			position = Vector3.new(0, 4, -28),
			size = Vector3.new(14, 8, 2),
			color = Color3.fromRGB(220, 180, 60),
			promptText = "Statistiken ansehen",
			promptKey = Enum.KeyCode.E,
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),
}

return HubConfig
