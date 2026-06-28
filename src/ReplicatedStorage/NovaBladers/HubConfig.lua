local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 0, 0),
	ARENA_ORIGIN = Vector3.new(200, 0, 0),

	HUB_RADIUS = 52,
	FLOOR_HEIGHT = 1,
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ZONE_CHECK_INTERVAL = 0.25,
	ZONE_HIGHLIGHT_COOLDOWN = 0.15,

	ZONES = {
		Training = {
			id = "Training",
			label = "Training Zone",
			modeLabel = "Modus: Training",
			mode = "Training",
			minPlayers = 1,
			position = Vector3.new(-22, 0, -18),
			size = Vector3.new(24, 6, 24),
			color = Color3.fromRGB(80, 140, 255),
		},
		Duel = {
			id = "Duel",
			label = "1v1 Duel",
			modeLabel = "Modus: 1v1 PvP",
			mode = "Duel",
			minPlayers = 2,
			maxPlayers = 2,
			position = Vector3.new(22, 0, -18),
			size = Vector3.new(24, 6, 24),
			color = Color3.fromRGB(255, 100, 90),
		},
		FFA = {
			id = "FFA",
			label = "FFA Arena",
			modeLabel = "Modus: Free-for-All",
			mode = "FFA",
			minPlayers = 3,
			position = Vector3.new(0, 0, 24),
			size = Vector3.new(28, 6, 24),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
