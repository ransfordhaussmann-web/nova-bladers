local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaGate = {
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 0, -48),
			size = Vector3.new(14, 10, 4),
			color = Color3.fromRGB(255, 90, 70),
			promptAction = "EnterArena",
			promptText = "Arena betreten",
		},
		BeyShop = {
			label = "Bey-Shop",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			promptAction = "OpenBeySelect",
			promptText = "Bey wählen",
		},
		StatsBoard = {
			label = "Ruhmeshalle",
			hint = "Deine Stats & Top-Spieler",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(12, 10, 4),
			color = Color3.fromRGB(255, 200, 60),
			promptAction = "RefreshStats",
			promptText = "Stats aktualisieren",
		},
	},
}

return HubConfig
