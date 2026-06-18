local HubWorldConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 4, 8),
	PLATFORM_SIZE = Vector3.new(96, 2, 96),
	PLATFORM_Y = 1,

	MODE_PADS = {
		{
			id = "Training",
			label = "Training",
			subtitle = "vs. Dummy",
			modeLabel = "Modus: Training",
			color = Color3.fromRGB(80, 180, 255),
			position = Vector3.new(-22, 2.5, -10),
			minPlayers = 1,
		},
		{
			id = "Duel",
			label = "1v1 PvP",
			subtitle = "Duell",
			modeLabel = "Modus: 1v1 PvP",
			color = Color3.fromRGB(255, 120, 80),
			position = Vector3.new(22, 2.5, -10),
			minPlayers = 2,
		},
		{
			id = "FFA",
			label = "FFA",
			subtitle = "Free-for-All",
			modeLabel = "Modus: FFA",
			color = Color3.fromRGB(180, 100, 255),
			position = Vector3.new(0, 2.5, -28),
			minPlayers = 3,
		},
	},

	BEY_KIOSK = {
		position = Vector3.new(0, 2.5, 18),
		label = "Bey-Auswahl",
	},

	LEADERBOARD_PODIUM = {
		position = Vector3.new(0, 2.5, 32),
		label = "Rangliste",
	},

	ARENA_SPAWN_NAMES = {
		Training = "TrainingSpawn",
		Duel = "DuelSpawn",
		FFA = "FFASpawn",
	},
}

return HubWorldConfig
