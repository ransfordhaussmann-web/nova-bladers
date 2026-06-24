local HubConfig = {
	ROOT_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR = {
		radius = 52,
		thickness = 2,
		color = Color3.fromRGB(28, 32, 48),
		material = Enum.Material.Slate,
	},

	RIM = {
		height = 3,
		thickness = 1.2,
		color = Color3.fromRGB(60, 80, 140),
		material = Enum.Material.Neon,
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 3, -34),
			size = Vector3.new(14, 10, 6),
			color = Color3.fromRGB(80, 140, 255),
			action = "enterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Werkstatt",
			hint = "Wähle deinen Bey",
			position = Vector3.new(34, 3, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 180, 60),
			action = "openBeySelect",
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Rangliste",
			hint = "Top 5 Spieler",
			position = Vector3.new(-34, 3, 0),
			size = Vector3.new(8, 12, 8),
			color = Color3.fromRGB(200, 160, 255),
			action = "showStats",
		},
		Training = {
			id = "Training",
			label = "Trainingsring",
			hint = "Solo gegen Dummy",
			position = Vector3.new(0, 3, 34),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(80, 200, 140),
			action = "enterArena",
		},
	},

	PROXIMITY = {
		maxActivationDistance = 10,
		holdDuration = 0,
	},

	LIGHTING = {
		ambient = Color3.fromRGB(45, 50, 70),
		brightness = 2.2,
		clockTime = 17.5,
	},
}

return HubConfig
