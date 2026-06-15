local HubConfig = {
	-- World root folder name under Workspace
	ROOT_NAME = "NovaHub",

	-- Character spawn in hub (Y includes floor height + half hip)
	SPAWN = Vector3.new(0, 4, -24),

	FLOOR = {
		size = Vector3.new(72, 1, 72),
		position = Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	},

	RIM = {
		height = 3,
		thickness = 2,
		color = Color3.fromRGB(55, 65, 90),
	},

	ZONES = {
		ArenaPortal = {
			id = "ArenaPortal",
			label = "Arena betreten",
			hint = "Lauf zum Portal oder drücke E",
			position = Vector3.new(0, 4, 28),
			size = Vector3.new(14, 10, 3),
			color = Color3.fromRGB(80, 160, 255),
			promptAction = "EnterArena",
			promptHold = 0,
		},
		StatsTerminal = {
			id = "StatsTerminal",
			label = "Statistik",
			hint = "Deine Wins, Losses und Rang",
			position = Vector3.new(-22, 4, 0),
			size = Vector3.new(6, 8, 4),
			color = Color3.fromRGB(90, 200, 140),
			promptAction = "ShowStats",
			promptHold = 0,
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Bestenliste",
			hint = "Top 5 Spieler global",
			position = Vector3.new(22, 4, 0),
			size = Vector3.new(10, 10, 1),
			color = Color3.fromRGB(255, 200, 80),
			promptAction = "ShowLeaderboard",
			promptHold = 0,
		},
		TrainingPad = {
			id = "TrainingPad",
			label = "Training",
			hint = "Solo gegen Dummy",
			position = Vector3.new(0, 4, -8),
			size = Vector3.new(10, 0.4, 10),
			color = Color3.fromRGB(120, 120, 160),
			promptAction = "EnterTraining",
			promptHold = 0.4,
		},
	},

	LIGHTING = {
		ambient = Color3.fromRGB(120, 130, 160),
		brightness = 2.5,
	},

	-- How close (studs) before contextual lobby UI appears
	TERMINAL_UI_RANGE = 14,
}

return HubConfig
