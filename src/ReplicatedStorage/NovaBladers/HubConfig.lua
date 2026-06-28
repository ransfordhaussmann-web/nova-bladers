local HubConfig = {
	-- Hub-Welt liegt neben der Arena; ARENA_ORIGIN im Place anpassen.
	HUB_ORIGIN = Vector3.new(0, 0, 200),
	ARENA_ORIGIN = Vector3.new(0, 0, 0),

	PLATFORM_RADIUS = 72,
	PLATFORM_HEIGHT = 3,

	SPAWN_OFFSET = Vector3.new(0, 5, 0),
	ZONE_CHECK_INTERVAL = 0.25,

	ZONES = {
		Training = {
			id = "Training",
			label = "Training",
			modeLabel = "Modus: Training",
			position = Vector3.new(-28, 0, 24),
			radius = 16,
			color = Color3.fromRGB(90, 170, 255),
			minPlayers = 1,
		},
		Duel = {
			id = "Duel",
			label = "1v1 Duel",
			modeLabel = "Modus: 1v1 PvP",
			position = Vector3.new(28, 0, 24),
			radius = 16,
			color = Color3.fromRGB(255, 110, 90),
			minPlayers = 2,
		},
		FFA = {
			id = "FFA",
			label = "Free-For-All",
			modeLabel = "Modus: FFA",
			position = Vector3.new(0, 0, -32),
			radius = 20,
			color = Color3.fromRGB(170, 100, 255),
			minPlayers = 3,
		},
	},
}

return HubConfig
