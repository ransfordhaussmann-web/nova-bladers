local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_CENTER = Vector3.new(0, 0, 120),
	HUB_PLATFORM_RADIUS = 28,
	HUB_SPAWN_OFFSET = Vector3.new(0, 4, 0),

	PORTALS = {
		Training = {
			label = "Training",
			modeLabel = "Modus: Training",
			color = Color3.fromRGB(80, 180, 255),
			offset = Vector3.new(-14, 2, 8),
			playerMode = "Training",
		},
		PvP = {
			label = "1v1 PvP",
			modeLabel = "Modus: 1v1 PvP",
			color = Color3.fromRGB(255, 120, 80),
			offset = Vector3.new(0, 2, 16),
			playerMode = "PvP",
		},
		FFA = {
			label = "FFA",
			modeLabel = "Modus: Free-for-All",
			color = Color3.fromRGB(180, 100, 255),
			offset = Vector3.new(14, 2, 8),
			playerMode = "FFA",
		},
	},

	BEY_STATION_OFFSET = Vector3.new(0, 2, -10),
	STATS_BOARD_OFFSET = Vector3.new(0, 6, -18),

	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
