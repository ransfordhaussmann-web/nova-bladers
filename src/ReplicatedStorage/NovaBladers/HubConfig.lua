local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_SPAWN_OFFSET = Vector3.new(0, 4, 10),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(96, 1, 96),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),

	ZONES = {
		Kiosk = {
			position = Vector3.new(-22, 2, -12),
			size = Vector3.new(10, 6, 8),
			color = Color3.fromRGB(50, 90, 160),
			label = "Stats Terminal",
			action = "kiosk",
			promptText = "Stats anzeigen",
		},
		ArenaGate = {
			position = Vector3.new(0, 4, -38),
			size = Vector3.new(14, 10, 4),
			color = Color3.fromRGB(200, 80, 80),
			label = "Arena Gate",
			action = "arena",
			promptText = "Arena betreten",
		},
		BeyBay = {
			position = Vector3.new(22, 2, -12),
			size = Vector3.new(10, 6, 8),
			color = Color3.fromRGB(140, 80, 220),
			label = "Bey Bay",
			action = "beyselect",
			promptText = "Bey wählen",
		},
	},

	PROMPT_HOLD = 0.4,
	PROMPT_DISTANCE = 10,
}

return HubConfig
