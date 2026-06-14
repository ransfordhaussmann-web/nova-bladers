local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_SIZE = Vector3.new(120, 1, 120),
	HUB_CENTER = Vector3.new(0, 0.5, 0),
	SPAWN_OFFSET = Vector3.new(0, 3, -40),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			actionText = "Arena betreten",
			objectText = "Arena-Tor",
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(90, 160, 255),
		},
		BeyShop = {
			name = "Bey-Shop",
			actionText = "Bey wählen",
			objectText = "Bey-Shop",
			position = Vector3.new(-38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 180, 60),
		},
		StatsBoard = {
			name = "Ruhmeshalle",
			actionText = "Stats anzeigen",
			objectText = "Ruhmeshalle",
			position = Vector3.new(38, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(140, 220, 140),
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 4, 0),
}

return HubConfig
