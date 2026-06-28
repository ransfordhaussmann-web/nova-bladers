local HubConfig = {
	-- Walkable hub platform (studs)
	HUB_RADIUS = 52,
	FLOOR_HEIGHT = 1.2,
	SPAWN_OFFSET = Vector3.new(0, 4, -6),

	-- Arena teleport offset (Studio place should align Arena origin here)
	ARENA_ORIGIN = Vector3.new(0, 5, 200),

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 85),
		Rim = Color3.fromRGB(60, 80, 140),
		Neon = Color3.fromRGB(100, 180, 255),
		Pillar = Color3.fromRGB(35, 40, 60),
	},

	ZONES = {
		Training = {
			id = "Training",
			label = "Training",
			mode = "training",
			modeLabel = "Modus: Training",
			position = Vector3.new(-28, 0, -22),
			color = Color3.fromRGB(80, 200, 255),
			minPlayers = 1,
		},
		Duel = {
			id = "Duel",
			label = "1v1 Duell",
			mode = "duel",
			modeLabel = "Modus: 1v1 PvP",
			position = Vector3.new(28, 0, -22),
			color = Color3.fromRGB(255, 120, 80),
			minPlayers = 2,
		},
		FFA = {
			id = "FFA",
			label = "FFA Arena",
			mode = "ffa",
			modeLabel = "Modus: Free-for-All",
			position = Vector3.new(0, 0, 32),
			color = Color3.fromRGB(180, 100, 255),
			minPlayers = 3,
		},
	},
}

return HubConfig
