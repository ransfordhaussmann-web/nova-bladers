local HubConfig = {
	ROOT_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, 8),
	FLOOR_RADIUS = 58,
	FLOOR_HEIGHT = 2,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 85),
		Trim = Color3.fromRGB(90, 180, 255),
		Training = Color3.fromRGB(80, 200, 140),
		OneVOne = Color3.fromRGB(255, 170, 70),
		FFA = Color3.fromRGB(220, 90, 255),
		BeySelect = Color3.fromRGB(120, 200, 255),
	},

	ZONES = {
		Training = {
			id = "Training",
			label = "Training",
			position = Vector3.new(-32, 0, -28),
			prompt = "Training Arena",
			description = "Übe gegen einen Dummy.",
			minPlayers = 1,
		},
		OneVOne = {
			id = "OneVOne",
			label = "1v1 PvP",
			position = Vector3.new(0, 0, -42),
			prompt = "1v1 Arena",
			description = "Duell gegen einen Gegner.",
			minPlayers = 2,
		},
		FFA = {
			id = "FFA",
			label = "FFA",
			position = Vector3.new(32, 0, -28),
			prompt = "FFA Arena",
			description = "Free-for-All ab 3 Spielern.",
			minPlayers = 3,
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey wählen",
			position = Vector3.new(0, 0, 30),
			prompt = "Bey-Auswahl",
			description = "Wähle deinen Nova Blader.",
		},
	},

	BOARDS = {
		Leaderboard = {
			position = Vector3.new(-50, 6, 0),
			face = Enum.NormalId.Right,
			title = "🏆 Top Spieler",
		},
		Stats = {
			position = Vector3.new(50, 6, 0),
			face = Enum.NormalId.Left,
			title = "Deine Stats",
		},
	},

	PROMPT = {
		ActionText = "Betreten",
		HoldDuration = 0,
		MaxActivationDistance = 10,
	},
}

return HubConfig
