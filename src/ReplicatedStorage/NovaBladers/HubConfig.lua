local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	ORIGIN = Vector3.new(0, 0, 200),
	SPAWN_OFFSET = Vector3.new(0, 4, 20),
	FLOOR_SIZE = Vector3.new(140, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 48, 58),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 6, -42),
			size = Vector3.new(18, 14, 6),
			color = Color3.fromRGB(90, 130, 255),
			title = "Arena-Tor",
			subtitle = "Match starten",
			prompt = "Arena betreten",
			emoji = "⚔️",
		},
		BeyShop = {
			position = Vector3.new(-42, 5, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 180, 70),
			title = "Bey-Shop",
			subtitle = "Bey wählen",
			prompt = "Bey auswählen",
			emoji = "🛒",
		},
		StatsBoard = {
			position = Vector3.new(42, 7, 0),
			size = Vector3.new(12, 14, 3),
			color = Color3.fromRGB(70, 200, 140),
			title = "Ruhmeshalle",
			subtitle = "Stats & Top 5",
			prompt = "Stats anzeigen",
			emoji = "🏆",
		},
	},

	PROMPT = {
		MaxActivationDistance = 12,
		HoldDuration = 0,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 6, 0),
}

return HubConfig
