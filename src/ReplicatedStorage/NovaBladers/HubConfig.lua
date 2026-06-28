local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 120),

	SPAWN = CFrame.new(0, 3, 95),
	ARENA_ENTRY = CFrame.new(0, 3, 36),

	PLATFORM_SIZE = Vector3.new(80, 2, 70),
	PLATFORM_COLOR = Color3.fromRGB(28, 32, 48),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),
	GLOW_COLOR = Color3.fromRGB(120, 200, 255),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 4, 148),
			radius = 10,
			prompt = "Arena betreten",
			action = "enterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-28, 4, 108),
			radius = 9,
			prompt = "Bey wählen",
			action = "openBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(28, 4, 108),
			radius = 9,
			prompt = "Statistiken ansehen",
			action = "showStats",
		},
	},
}

return HubConfig
