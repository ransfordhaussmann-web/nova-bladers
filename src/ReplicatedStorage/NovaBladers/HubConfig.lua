local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	-- World layout (studs)
	PLATFORM_SIZE = Vector3.new(140, 2, 140),
	PLATFORM_CENTER = Vector3.new(0, 0, 0),
	SPAWN_OFFSET = Vector3.new(0, 5, 20),

	ZONES = {
		ArenaPortal = {
			position = Vector3.new(0, 3, -48),
			promptText = "Arena betreten",
			promptKey = Enum.KeyCode.E,
			maxDistance = 12,
		},
		BeyStation = {
			position = Vector3.new(-42, 3, 0),
			promptText = "Bey wählen",
			promptKey = Enum.KeyCode.E,
			maxDistance = 10,
		},
		StatsKiosk = {
			position = Vector3.new(42, 3, 0),
		},
		Leaderboard = {
			position = Vector3.new(0, 3, 42),
		},
	},

	-- Visual theme (Nova Bladers — eigenes IP)
	COLORS = {
		Platform = Color3.fromRGB(28, 32, 48),
		Trim = Color3.fromRGB(70, 120, 255),
		Portal = Color3.fromRGB(120, 200, 255),
		BeyStation = Color3.fromRGB(255, 200, 60),
		Accent = Color3.fromRGB(140, 80, 220),
	},

	TELEPORT = {
		HubYOffset = 4,
		ArenaYOffset = 6,
		ArenaCenter = Vector3.new(0, 0, 200),
	},

	LEADERBOARD_COUNT = 5,
}

return HubConfig
