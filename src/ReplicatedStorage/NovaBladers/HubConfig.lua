local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			actionText = "Arena betreten",
			objectText = "Arena-Tor",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(14, 8, 4),
			color = Color3.fromRGB(255, 120, 60),
			holdDuration = 0,
		},
		BeyShop = {
			name = "Bey-Shop",
			actionText = "Bey wählen",
			objectText = "Bey-Shop",
			position = Vector3.new(-38, 2, 10),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(80, 140, 255),
			holdDuration = 0,
		},
		StatsBoard = {
			name = "Ruhmeshalle",
			actionText = "Statistiken anzeigen",
			objectText = "Ruhmeshalle",
			position = Vector3.new(38, 2, 10),
			size = Vector3.new(10, 8, 4),
			color = Color3.fromRGB(255, 210, 80),
			holdDuration = 0,
		},
	},
}

return HubConfig
