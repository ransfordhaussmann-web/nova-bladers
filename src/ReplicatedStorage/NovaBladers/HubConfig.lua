local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	ARENA_SPAWN_FALLBACK = Vector3.new(0, 5, 0),

	FLOOR_SIZE = Vector3.new(72, 1, 72),
	FLOOR_POSITION = Vector3.new(0, 0.5, 0),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),

	ZONES = {
		ArenaGate = {
			label = "Arena-Tor",
			position = Vector3.new(0, 2, -28),
			size = Vector3.new(14, 1, 8),
			color = Color3.fromRGB(255, 95, 80),
			promptAction = "Arena betreten",
		},
		BeyShop = {
			label = "Bey-Shop",
			position = Vector3.new(-26, 2, 0),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(80, 150, 255),
			promptAction = "Bey wählen",
		},
		StatsBoard = {
			label = "Ruhmeshalle",
			position = Vector3.new(26, 2, 0),
			size = Vector3.new(10, 1, 10),
			color = Color3.fromRGB(255, 200, 70),
			promptAction = "Stats anzeigen",
		},
	},
}

return HubConfig
