local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN = CFrame.new(0, 3, 20),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_POSITION = Vector3.new(0, 0.5, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E — in die Arena!",
			position = Vector3.new(0, 3, -42),
			size = Vector3.new(22, 10, 8),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
			promptText = "Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-38, 3, 8),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(70, 130, 255),
			action = "openBeySelect",
			promptText = "Bey auswählen",
		},
		FameHall = {
			id = "FameHall",
			label = "Ruhmeshalle",
			hint = "Globales Leaderboard",
			position = Vector3.new(38, 3, 8),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 195, 50),
			action = "showLeaderboard",
			promptText = "Leaderboard ansehen",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 7, 18),
		size = Vector3.new(14, 9, 0.4),
		face = Enum.NormalId.Front,
	},

	PROXIMITY_DISTANCE = 10,
}

return HubConfig
