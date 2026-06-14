local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	SPAWN_OFFSET = Vector3.new(0, 4, 18),

	ZONES = {
		ArenaGate = {
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 0, -24),
			size = Vector3.new(10, 8, 3),
			color = Color3.fromRGB(90, 150, 255),
			action = "enterArena",
		},
		BeyShop = {
			label = "Bey-Werkstatt",
			hint = "Wähle deinen Nova Bey",
			position = Vector3.new(-22, 0, 4),
			size = Vector3.new(8, 6, 8),
			color = Color3.fromRGB(255, 180, 70),
			action = "openBeySelect",
		},
		StatsBoard = {
			label = "Ruhmeshalle",
			hint = "Stats & Bestenliste",
			position = Vector3.new(22, 0, 4),
			size = Vector3.new(8, 6, 8),
			color = Color3.fromRGB(180, 120, 255),
			action = "showStats",
		},
	},

	PROMPT_DISTANCE = 10,
	PROMPT_HOLD = 0,
}

return HubConfig
