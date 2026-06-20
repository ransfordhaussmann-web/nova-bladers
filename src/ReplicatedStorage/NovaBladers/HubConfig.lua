local HubConfig = {
	ORIGIN = Vector3.new(0, 80, 0),
	FLOOR_SIZE = Vector3.new(96, 2, 96),
	SPAWN_OFFSET = Vector3.new(0, 5, 28),
	EDGE_WALL_HEIGHT = 8,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena Gate",
			hint = "Drücke E oder tippe Start — Match beginnt",
			position = Vector3.new(0, 0, -32),
			size = Vector3.new(16, 10, 8),
			color = Color3.fromRGB(255, 120, 80),
			promptText = "Arena betreten",
			action = "enterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey Garage",
			hint = "Wähle deinen Bey vor dem Kampf",
			position = Vector3.new(32, 0, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			promptText = "Bey wählen",
			action = "openBeySelect",
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Rank Board",
			hint = "Top 5 Spieler weltweit",
			position = Vector3.new(-32, 0, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 210, 60),
			promptText = "Leaderboard ansehen",
			action = "showLeaderboard",
		},
		StatsKiosk = {
			id = "StatsKiosk",
			label = "Stats Terminal",
			hint = "Deine Wins, Losses und Rang",
			position = Vector3.new(0, 0, 32),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(120, 220, 160),
			promptText = "Stats ansehen",
			action = "showStats",
		},
	},
}

return HubConfig
