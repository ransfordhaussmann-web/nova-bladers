local HubConfig = {
	ROOT_NAME = "NovaBladersHub",
	SPAWN_CFRAME = CFrame.new(0, 4, 8),

	FLOOR_RADIUS = 42,
	FLOOR_THICKNESS = 2,

	ARENA_GATE = {
		position = Vector3.new(0, 6, -32),
		size = Vector3.new(14, 12, 4),
		promptText = "Arena betreten",
		promptAction = "EnterArena",
	},
	BEY_FORGE = {
		position = Vector3.new(-28, 4, 0),
		size = Vector3.new(10, 8, 10),
		label = "Bey-Schmiede",
		subtitle = "Wähle deinen Bey",
	},
	LEADERBOARD = {
		position = Vector3.new(28, 4, 0),
		size = Vector3.new(10, 12, 4),
		label = "Rangliste",
	},
	TRAINING_PAD = {
		position = Vector3.new(0, 4, 28),
		size = Vector3.new(16, 1, 12),
		label = "Trainings-Info",
	},

	COLORS = {
		floor = Color3.fromRGB(28, 32, 48),
		floorAccent = Color3.fromRGB(45, 55, 90),
		railing = Color3.fromRGB(90, 110, 180),
		portal = Color3.fromRGB(80, 160, 255),
		portalGlow = Color3.fromRGB(120, 200, 255),
		forge = Color3.fromRGB(255, 170, 60),
		leaderboard = Color3.fromRGB(255, 215, 80),
		training = Color3.fromRGB(100, 220, 140),
	},

	AMBIENT = Color3.fromRGB(70, 80, 120),
	OUTDOOR_AMBIENT = Color3.fromRGB(90, 100, 140),
	BRIGHTNESS = 2.2,
	CLOCK_TIME = 17.5,
}

return HubConfig
