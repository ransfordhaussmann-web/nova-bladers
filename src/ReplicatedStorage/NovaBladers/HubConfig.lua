local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",
	ARENA_SPAWN_NAME = "Spawn",

	HUB_ORIGIN = Vector3.new(0, 0, 200),
	FLOOR_SIZE = Vector3.new(120, 1, 120),

	SPAWN_OFFSET = Vector3.new(0, 4, 35),
	PROMPT_DISTANCE = 12,
	PROMPT_HOLD = 0,

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			hint = "Match starten",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 110, 70),
			action = "arena",
		},
		BeyShop = {
			name = "Bey-Werkstatt",
			hint = "Bey wählen",
			position = Vector3.new(-38, 2, 18),
			size = Vector3.new(10, 6, 10),
			color = Color3.fromRGB(70, 150, 255),
			action = "beySelect",
		},
		StatsBoard = {
			name = "Ruhmeshalle",
			hint = "Stats anzeigen",
			position = Vector3.new(38, 2, 18),
			size = Vector3.new(12, 8, 4),
			color = Color3.fromRGB(255, 200, 70),
			action = "stats",
		},
	},
}

return HubConfig
