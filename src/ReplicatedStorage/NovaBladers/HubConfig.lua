local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_SPAWN = Vector3.new(0, 4, 0),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(32, 36, 48),
	ACCENT_COLOR = Color3.fromRGB(70, 130, 255),

	PROMPT_DISTANCE = 12,
	PROMPT_HOLD = 0,

	ZONES = {
		ArenaGate = {
			label = "Arena-Tor",
			actionText = "Arena betreten",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(14, 8, 3),
			color = Color3.fromRGB(255, 90, 70),
			interactType = "Arena",
		},
		BeyForge = {
			label = "Bey-Schmiede",
			actionText = "Bey wählen",
			position = Vector3.new(-38, 2, 28),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(80, 200, 255),
			interactType = "BeySelect",
		},
		StatsPodium = {
			label = "Ehrenhalle",
			actionText = "Stats ansehen",
			position = Vector3.new(38, 2, 28),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(255, 210, 80),
			interactType = "Stats",
		},
	},
}

return HubConfig
