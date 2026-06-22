local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.Bowl.Spawn",
		"Workspace.Arena.Spawn",
	},

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 3, 28),
			size = Vector3.new(14, 8, 8),
			color = Color3.fromRGB(255, 110, 70),
			action = "enterArena",
			promptKey = Enum.KeyCode.E,
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-32, 3, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
			promptKey = Enum.KeyCode.E,
		},
		{
			id = "hallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(32, 3, 0),
			size = Vector3.new(12, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			action = "viewLeaderboard",
			promptKey = Enum.KeyCode.E,
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 8, -6),
		size = Vector3.new(10, 6, 0.5),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
