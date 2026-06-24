local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3, 20),
	HUB_FOLDER = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	THEME = {
		floor = Color3.fromRGB(35, 40, 55),
		wall = Color3.fromRGB(50, 55, 75),
		accent = Color3.fromRGB(80, 140, 255),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena — Training, 1v1 oder FFA.",
			position = Vector3.new(0, 1, -28),
			size = Vector3.new(18, 8, 6),
			color = Color3.fromRGB(255, 120, 80),
			action = "arena",
			promptText = "Arena betreten",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey vor dem Kampf.",
			position = Vector3.new(-28, 1, 8),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 200, 255),
			action = "beySelect",
			promptText = "Bey wählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Die besten Nova Bladers aller Zeiten.",
			position = Vector3.new(28, 1, 8),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 210, 80),
			action = "leaderboard",
			promptText = "Rangliste ansehen",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.Spawn",
		"Workspace.Bowl.Spawn",
	},
}

return HubConfig
