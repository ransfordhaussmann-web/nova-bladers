local HubWorldConfig = {
	SPAWN = Vector3.new(0, 4, 8),
	PLATFORM_RADIUS = 52,
	PLATFORM_HEIGHT = 1.2,
	BOUNDARY_HEIGHT = 12,

	THEME = {
		floor = Color3.fromRGB(22, 26, 36),
		floorAccent = Color3.fromRGB(45, 55, 78),
		trim = Color3.fromRGB(80, 140, 255),
		trimSecondary = Color3.fromRGB(255, 180, 60),
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 0.6, -34),
			size = Vector3.new(16, 1.2, 12),
			color = Color3.fromRGB(70, 210, 110),
			promptText = "Arena betreten",
			action = "enterArena",
		},
		BeyForge = {
			id = "BeyForge",
			label = "Bey-Schmiede",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-30, 0.6, -8),
			size = Vector3.new(12, 1.2, 12),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			action = "beySelect",
		},
		TrainingRing = {
			id = "TrainingRing",
			label = "Trainings-Ring",
			hint = "Übe gegen einen Dummy",
			position = Vector3.new(30, 0.6, -8),
			size = Vector3.new(12, 1.2, 12),
			color = Color3.fromRGB(255, 200, 70),
			promptText = "Training starten",
			action = "enterArena",
		},
	},

	LEADERBOARD = {
		position = Vector3.new(0, 0, 38),
		size = Vector3.new(10, 9, 1.2),
		label = "Global Leaderboard",
	},

	DECOR = {
		pillarCount = 8,
		pillarRadius = 44,
		pillarHeight = 14,
	},
}

return HubWorldConfig
